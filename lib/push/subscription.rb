require 'securerandom'

module Push
  class Subscription
    attr_reader :subscriber_id

    def initialize(subscriber_id=nil)
      @subscriber_id = subscriber_id || self.class.subscriber_id
    end

    def subscribe(path, &block)
      queue_name  = "#{subscriber_id}@#{path}"
      channel     = AMQP::Channel.new(Push.amqp.connection).prefetch(1)
      exchange    = AMQP::Exchange.new(channel, :fanout, path, :auto_delete => true)
      queue       = AMQP::Queue.new(channel, queue_name, :arguments => {'x-expires' => ttl})
      queue.bind(exchange)

      # When we get a message, we want to remove the consumer from the queue so that the x-expires
      # ttl starts ticking down. On the reconnect, the consumer connects to the queue and resets the
      # timer on x-expires... in theory at least.
      @consumer = AMQP::Consumer.new(channel, queue, subscriber_id)
      @consumer.on_delivery do |metadata, payload|
        p [:get, subscriber_id, @consumer.consumer_tag, path, payload]
        block.call(payload)
        # The ack needs to go after the block is called. This makes sure that all processing
        # happens downstream before we remove it from the queue entirely.
        metadata.ack
      end.consume
    end

    def unsubscribe
      @consumer.cancel if @consumer
    end

    # The time that a queue should live *after* the client unsubscribes. This is useful for
    # flakey network connections, like HTTP Long Polling or even broken web sockets.
    def ttl
      15000
    end

  protected
    def self.subscriber_id
      SecureRandom.uuid
    end
  end
end