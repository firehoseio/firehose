module Firehose
  class Subscription
    # consumer_id and channel for the subscription.
    attr_reader :consumer_id

    # Channel that we'll use for the pub-sub activity. This probably maps to an URL
    attr_reader :channel

    def initialize(consumer_id, channel)
      @consumer_id, @channel = consumer_id, channel
    end

    # Subscribe to messages on the backend to fill up the subscription queue. consumer_ids of the messages
    # will queue up units of "work" to process data from the subscription.
    def subscribe(&block)
      redis.subscribe(channel)
      redis.on(:message) do |channel, message|
        Firehose.logger.debug "Redis recieved `#{message}` to `#{consumer_id}@#{channel}`"
        block.call message, self
      end
      Firehose.logger.debug "Redis subscribed to `#{consumer_id}@#{channel}`"
      self # Return the subscription for chaining.
    end

    def unsubscribe(&block)
      redis.unsubscribe(channel) do
        Firehose.logger.debug "Redis unsubscribed from `#{consumer_id}@#{channel}`"
        redis.close
        block.call(self) if block
      end
      self
    end

  private
    def redis
      @redis ||= EM::Hiredis.connect
    end
  end

  # Queue subscription messages so that we can remember and/or operate on them
  class Subscription::Queue
    attr_reader :subscription, :channel

    def initialize(consumer_id, channel)
      @subscription = Subscription.new(consumer_id, channel)
      # Start the subscription and start dropping mesasge onto the queue
      subscription.subscribe do |message|
        queue.push message
      end
    end

    # Pop an item off the subscription queue so we can work on it.
    def pop(&block)
      queue.pop do |message|
        block.call message, subscription
      end
    end

    # Kill the queue in n seconds.
    def kill(ttl=0, &block)
      if ttl.zero?
        subscription.unsubscribe &block
      else
        @timer = EM::Timer.new(ttl){ kill 0 }
      end
    end

    def live
      @timer.cancel if @timer
    end

  private
    def queue
      @queue ||= EM::Queue.new
    end
  end
end