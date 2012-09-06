module Firehose
  class Publisher
    
    MAX_MESSAGES = 100
    TTL = 60*60*24  # 1 day of time, yay!
    PAYLOAD_DELIMITER = "\n"

    def publish(channel_key, message, opts={})
      # How long should we hang on to the resource once is published?
      ttl = (opts[:ttl] || TTL).to_i

      # TODO hi-redis isn't that awesome... we have to setup an errback per even for wrong
      # commands because of the lack of a method_missing whitelist. Perhaps implement a whitelist in
      # em-hiredis or us a diff lib?
      deferrable = EM::DefaultDeferrable.new
      deferrable.errback {|e| EM.next_tick { raise e } }

      if @publish_script_digest.nil?
        register_publish_script.errback do |e|
          deferrable.fail e
        end.callback do |digest|
          @publish_script_digest = digest
          Firehose.logger.debug "Registered Lua publishing script with Redis => #{digest}"
          eval_publish_script channel_key, message, ttl, deferrable
        end
      else
        eval_publish_script channel_key, message, ttl, deferrable
      end

      deferrable
    end

  private
    def key(*segments)
      segments.unshift(:firehose).join(':')
    end

    def redis
      @redis ||= EM::Hiredis.connect
    end

    def self.to_payload(channel_key, sequence, message)
      [channel_key, sequence, message].join(PAYLOAD_DELIMITER)
    end

    def self.from_payload(payload)
      payload.split(PAYLOAD_DELIMITER, method(:to_payload).arity)
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

    def eval_publish_script(channel_key, message, ttl, deferrable)
      list_key = key(channel_key, :list)
      script_args = [
        key(channel_key, :sequence),
        list_key,
        key(:channel_updates),
        ttl,
        message,
        MAX_MESSAGES,
        PAYLOAD_DELIMITER
      ]
      Firehose.logger.debug "Evaluating Lua publishing script (#{@publish_script_digest}) with arguments: #{script_args.inspect}"
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
      local max_messages      = KEYS[6]
      local payload_delimiter = KEYS[7]

      local current_sequence = redis.call('get', sequence_key)
      if current_sequence == nil or current_sequence == false then
        current_sequence = 0
      end

      local sequence = current_sequence + 1
      local message_payload = channel_key .. payload_delimiter .. sequence .. payload_delimiter .. message

      redis.call('set', sequence_key, sequence)
      redis.call('expire', sequence_key, ttl)
      redis.call('lpush', list_key, message)
      redis.call('ltrim', list_key, 0, max_messages - 1)
      redis.call('expire', list_key, ttl)
      redis.call('publish', channel_key, message_payload)

      return sequence
    LUA

  end
end
