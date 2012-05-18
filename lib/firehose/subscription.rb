module Firehose
  class Subscription
    # Channel that we'll use for the pub-sub activity. This probably maps to an URL
    attr_reader :channel

    def initialize(channel)
      @channel = channel
    end

    def next_message(sequence=nil)
      deferrable = EM::DefaultDeferrable.new
    end

    def subscribe(sequence = nil, &block)
      redis_sub = EM::Hiredis.connect
      redis_sub.subscribe key(:channel_updates)
      redis_sub.on(:message) do |channel, message|
        Firehose.logger.debug "Redis received `#{message}` to `#{channel}`"
        redis.multi # do
        redis.index(key(channel, :list), 0).callback do |message|
          redis.get(key(channel, :sequence)).callback do |sequence|
            block.call message, sequence, self
          end
        end
        redis.exec # end

      end
      Firehose.logger.debug "Redis subscribed to `#{channel}`"
      self # Return the subscription for chaining.
    end

    def unsubscribe(&block)
      redis.unsubscribe(channel)
      Firehose.logger.debug "Redis unsubscribed from `#{channel}`"
      redis.close_connection
      @redis = nil
      block.call(self) if block
      self
    end

    def redis
      self.class.redis
    end

  private
    def key(*segments)
      segments.unshift(:firehose).join(':')
    end

    def self.redis
      @redis ||= EM::Hiredis.connect
    end
  end
end