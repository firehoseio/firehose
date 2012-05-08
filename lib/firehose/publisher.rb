module Firehose
  class Publisher
    def publish(channel, message)
      Firehose.logger.debug "Redis publishing `#{message}` to `#{channel}`"
      redis.publish(channel, message).errback { raise 'Error publishing' }
    end

  private
    def redis
      @redis ||= EM::Hiredis.connect
    end
  end
end