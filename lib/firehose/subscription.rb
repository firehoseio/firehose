module Firehose
  class Subscription
    # Default TTL for how long a subscription should live on the server when the
    # consumer disconnects.
    # TODO should the Consumer handle TTL?
    TTL = 15000

    # Time to live for the amqp_queue on the server after the subscription is canceled. This
    # is mostly for flakey connections where the client may reconnect after *ttl* and continue
    # receiving messages.
    attr_accessor :ttl

    # Consumer and channel for the subscription.
    attr_reader :consumer

    # Channel that we'll use for the pub-sub activity. This probably maps to an URL
    attr_reader :channel

    def initialize(consumer, channel)
      @consumer, @channel = consumer, channel
    end

    # TODO - Move the channel to an initializer so that we can force on AMQP subscription per one
    # Firehose subscription. As it stands now, you could fire off multple subscriptions to diff amqp_channels
    def subscribe(&block)
      amqp_queue_name = "#{consumer.guid}@#{channel}"
      amqp_channel    = AMQP::Channel.new(Firehose.amqp.connection).prefetch(1)
      amqp_exchange   = AMQP::Exchange.new(amqp_channel, :fanout, channel, :auto_delete => true)
      amqp_queue      = AMQP::Queue.new(amqp_channel, amqp_queue_name, :arguments => {'x-expires' => ttl})
      amqp_queue.bind(amqp_exchange)

      # When we get a message, we want to remove the consumer from the amqp_queue so that the x-expires
      # ttl starts ticking down. On the reconnect, the consumer connects to the amqp_queue and resets the
      # timer on x-expires... in theory at least.
      @amqp_consumer = AMQP::Consumer.new(amqp_channel, amqp_queue, consumer.guid)
      @amqp_consumer.on_delivery do |metadata, message|
        Firehose.logger.debug "AMQP delivering `#{message}` to `#{consumer.guid}@#{channel}`"
        block.call(message, self)
        # The ack needs to go after the block is called. This makes sure that all processing
        # happens downstream before we remove it from the amqp_queue entirely.
        metadata.ack
      end.consume
      Firehose.logger.debug "AMQP subscribed to `#{consumer.guid}@#{channel}`"
      self # Return the subscription for chaining.
    end

    def unsubscribe
      Firehose.logger.debug "AMQP unsubscribed"
      @amqp_consumer.cancel if @amqp_consumer
      @unsubscribe_callback.call self if @unsubscribe_callback
    end

    # Callback when consumer unsubscribes from subscription. The consumer uses this to remove 
    # subscriptions from itself when an unsubscribe happens.
    def on_unsubscribe(&block)
      @unsubscribe_callback = block
    end

    # The time that a amqp_queue should live *after* the client unsubscribes. This is useful for
    # flakey network connections, like HTTP Long Polling or even broken web sockets.
    def ttl
      @ttl ||= TTL
    end
  end
end