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

      # TODO: Use HSET so we don't have to pull 100 messages back every time.
      redis.multi
        redis.lpush(list_key, message)
          .errback{|e| deferrable.fail e }
        redis.ltrim(list_key, 0, MAX_MESSAGES - 1)
          .errback{|e| deferrable.fail e }
        redis.expire(list_key, TTL)
          .errback{|e| deferrable.fail e }
        redis.incr(sequence_key)
          .errback{|e| deferrable.fail e }
        redis.expire(sequence_key, TTL)
          .errback{|e| deferrable.fail e }
      redis.exec
        .errback{|e| deferrable.fail e }
        .callback { |(_, _, _, sequence, _)|
          Firehose.logger.debug "Redis stored `#{message}` to list `#{list_key}` with sequence `#{sequence}`"
          redis.publish(key(:channel_updates), self.class.to_payload(channel_key, sequence, message))
            .errback{|e| deferrable.fail e }
            .callback do
              Firehose.logger.debug "Redis published `#{message}` to `#{channel_key}`"
              deferrable.succeed
            end
        }

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
  end
end
