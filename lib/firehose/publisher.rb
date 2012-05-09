module Firehose
  class Publisher
    def publish(channel, message)
      Firehose.logger.debug "Redis publishing `#{message}` to `#{channel}`"
      redis.publish(channel, message).errback { |msg| raise "Error publishing: #{msg}" }
    end

  private
    def redis
      @redis ||= EM::Hiredis.connect
    end
  end
end