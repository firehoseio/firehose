module Firehose
  class Publisher
    MAX_MESSAGES = 100
    TTL = 60*60*24  # 1 day of time, yay!
    PAYLOAD_DELIMITER = "\n"

    def publish(channel_key, message)
      # TODO hi-redis isn't that awesome... we have to setup an errback per even for wrong
      # commands because of the lack of a method_missing whitelist. Perhaps implement a whitelist in
      # em-hiredis or us a diff lib?
      deferrable = EM::DefaultDeferrable.new
      deferrable.errback {|e| raise e }

      # DRY up keys a little bit for the epic publish command to come.
      list_key = key(channel_key, :list)
      sequence_key = key(channel_key, :sequence)

      redis.eval(%(local current_sequence = redis.call('get', KEYS[1])
                   if (current_sequence == nil) or (current_sequence == false)
                   then
                     current_sequence = 0
                   end
                   local sequence = current_sequence + 1
                   redis.call('set', KEYS[1], sequence)
                   redis.call('expire', KEYS[1], #{TTL})
                   redis.call('lpush', KEYS[2], "#{lua_escape(message)}")
                   redis.call('ltrim', KEYS[2], 0, #{MAX_MESSAGES - 1})
                   redis.call('expire', KEYS[2], #{TTL})
                   redis.call('publish', KEYS[3], "#{lua_escape(channel_key + PAYLOAD_DELIMITER)}" .. sequence .. "#{lua_escape(PAYLOAD_DELIMITER + message)}")
                   return sequence
                  ), 3, sequence_key, list_key, key(:channel_updates)).
        errback{|e| deferrable.fail e }.
        callback do |sequence|
          Firehose.logger.debug "Redis stored/published `#{message}` to list `#{list_key}` with sequence `#{sequence}`"
          deferrable.succeed
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
      str.gsub(/"/,'\"').gsub(/\n/,'\n')
    end
  end
end
