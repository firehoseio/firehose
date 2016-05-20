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
            eval_publish_script channel_key, message, ttl, buffer_size, deferrable
          end
        else
          eval_publish_script channel_key, message, ttl, buffer_size, deferrable
        end

        deferrable
      end

      private
      def redis
        @redis ||= EM::Hiredis.connect
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

      def eval_publish_script(channel_key, message, ttl, buffer_size, deferrable)
        list_key = Server.key(channel_key, :list)
        script_args = [
          Server.key(channel_key, :sequence),
          list_key,
          Server.key(:channel_updates),
          ttl,
          message,
          buffer_size,
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
        local buffer_size       = KEYS[6]
        local payload_delimiter = KEYS[7]
        local firehose_resource = KEYS[8]

        local current_sequence = redis.call('get', sequence_key)
        if current_sequence == nil or current_sequence == false then
          current_sequence = 0
        end

        local sequence = current_sequence + 1
        local message_payload = firehose_resource .. payload_delimiter .. sequence .. payload_delimiter .. message

        redis.call('set', sequence_key, sequence)
        redis.call('expire', sequence_key, ttl)
        redis.call('rpush', list_key, message)
        local list_size = redis.call('llen', list_key)
        if tonumber(buffer_size) < tonumber(list_size) then
          redis.call('ltrim', list_key, list_size - buffer_size, -1)
        end
        redis.call('expire', list_key, ttl)
        redis.call('publish', channel_key, message_payload)

        return sequence
      LUA

    end
  end
end
