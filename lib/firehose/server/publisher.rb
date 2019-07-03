module Firehose
  module Server
    class Publisher
      # Seconds that the message buffer should live before Redis expires it.
      TTL = 60*60*24

      # Delimited used to frame different parts of a message that's published
      # over Firehose.
      PAYLOAD_DELIMITER = "\n"

      # Publish a message to a Firehose channel via Redis.
      def publish(channel_key, message, opts={})
        # How long should we hang on to the resource once is published?
        ttl = (opts[:ttl] || TTL).to_i
        buffer_size = (opts[:buffer_size] || MessageBuffer::DEFAULT_SIZE).to_i
        persist = !!opts[:persist]

        if opts.include?(:deprecated)
          if opts[:deprecated]
            Server.configuration.deprecate_channel channel_key
          else
            Server.configuration.undeprecate_channel channel_key
          end
        end

        # TODO hi-redis isn't that awesome... we have to setup an errback per even for wrong
        # commands because of the lack of a method_missing whitelist. Perhaps implement a whitelist in
        # em-hiredis or us a diff lib?
        if (deferrable = opts[:deferrable]).nil?
          deferrable = EM::DefaultDeferrable.new
          deferrable.errback do |e|
            # Handle missing Lua publishing script in cache
            # (such as Redis restarting or someone executing SCRIPT FLUSH)
            if e.message =~ /NOSCRIPT/
              deferrable.succeed
              EM.next_tick do
                @publish_script_digest = nil
                combined_opts = opts.merge :deferrable => deferrable
                self.publish channel_key, message, combined_opts
              end
            else
              EM.next_tick { raise e }
            end
          end
        end

        if @publish_script_digest.nil?
          register_publish_script.errback do |e|
            deferrable.fail e
          end.callback do |digest|
            @publish_script_digest = digest
            Firehose.logger.debug "Registered Lua publishing script with Redis => #{digest}"
            eval_publish_script channel_key, message, ttl, buffer_size, persist, deferrable
          end
        else
          eval_publish_script channel_key, message, ttl, buffer_size, persist, deferrable
        end

        Firehose::Server.metrics.message_published!(channel_key, message)

        deferrable
      end

      private
      def redis
        @redis ||= Firehose::Server.redis.connection
      end

      # Serialize components of a message into something that can be dropped into Redis.
      def self.to_payload(channel_key, sequence, message)
        [channel_key, sequence, message].join(PAYLOAD_DELIMITER)
      end

      # Deserialize components of a message back into Ruby.
      def self.from_payload(payload)
        @payload_size ||= method(:to_payload).arity
        payload.split(PAYLOAD_DELIMITER, @payload_size)
      end

      # TODO: Make this FAR more robust. Ideally we'd whitelist the permitted
      #       characters and then escape or remove everything else.
      #       See: http://en.wikibooks.org/wiki/Lua_Programming/How_to_Lua/escape_sequence
      def lua_escape(str)
        str.gsub(/\\/,'\\\\\\').gsub(/"/,'\"').gsub(/\n/,'\n').gsub(/\r/,'\r')
      end

      def register_publish_script
        redis.script 'LOAD', REDIS_PUBLISH_SCRIPT
      end

      def eval_publish_script(channel_key, message, ttl, buffer_size, persist, deferrable)
        list_key = Server::Redis.key(channel_key, :list)
        script_args = [
          Server::Redis.key(channel_key, :sequence),
          list_key,
          Server::Redis.key(:channel_updates),
          ttl,
          message,
          buffer_size,
          persist,
          PAYLOAD_DELIMITER,
          channel_key
        ]

        redis.evalsha(
          @publish_script_digest, script_args.length, *script_args
        ).errback do |e|
          deferrable.fail e
        end.callback do |sequence|
          Firehose.logger.debug "Redis stored/published `#{message}` to list `#{list_key}` with sequence `#{sequence}`"
          deferrable.succeed
        end
      end

      REDIS_PUBLISH_SCRIPT = <<-LUA
        local sequence_key      = KEYS[1]
        local list_key          = KEYS[2]
        local channel_key       = KEYS[3]
        local ttl               = KEYS[4]
        local message           = KEYS[5]
        local buffer_size       = KEYS[6] + 0
        local persist           = KEYS[7] == "true"
        local payload_delimiter = KEYS[8]
        local firehose_resource = KEYS[9]

        local current_sequence = redis.call('get', sequence_key)
        if current_sequence == nil or current_sequence == false then
          current_sequence = 0
        end

        local sequence = current_sequence + 1
        local message_payload = firehose_resource .. payload_delimiter .. sequence .. payload_delimiter .. message

        redis.call('set', sequence_key, sequence)
        if buffer_size > 0 then
          redis.call('lpush', list_key, message)
          redis.call('ltrim', list_key, 0, buffer_size - 1)
        else
          redis.call('del', list_key)
        end

        redis.call('publish', channel_key, message_payload)

        if persist then
          redis.call('persist', sequence_key)
          redis.call('persist', list_key)
        else
          redis.call('expire', sequence_key, ttl)
          redis.call('expire', list_key, ttl)
        end

        return sequence
      LUA

    end
  end
end
