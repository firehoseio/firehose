module Firehose
  class Publisher
    MAX_MESSAGES = 10
    TTL = 60*60*24  # 1 day of time, yay!

    def publish(channel, message)
      Firehose.logger.debug "Redis publishing `#{message}` to `#{channel}`"
      redis.multi # do
        redis.lset    key(channel, :list), message
        redis.ltrim   key(channel, :list), 0, MAX_MESSAGES
        redis.incr    key(channel, :sequence)
        redis.expire  key(channel, :sequence), TTL
        redis.expire  key(channel, :list), TTL
        redis.publish(key(:channel_updates), channel).errback { |msg| raise "Error publishing: #{msg}" }
      redis.exec # end # heheheheh... talk the the em-hiredis author...
    end

  private
    def key(*segments)
      segments.unshift(:firehose).join(':')
    end

    def redis
      @redis ||= EM::Hiredis.connect
    end
  end
end