require 'securerandom'

module Push
  class Subscription
    attr_reader :sid

    def initialize(sid=nil)
      @sid = sid || self.class.sid
    end

    def subscribe(path, &block)
      queue_name  = "#{sid}@#{path}"
      channel     = AMQP::Channel.new(self.class.connection).prefetch(1)
      exchange    = AMQP::Exchange.new(channel, :fanout, path, :auto_delete => true)
      queue       = AMQP::Queue.new(channel, queue_name, :arguments => {'x-expires' => ttl})
      queue.bind(exchange)

      # When we get a message, we want to remove the consumer from the queue so that the x-expires
      # ttl starts ticking down. On the reconnect, the consumer connects to the queue and resets the
      # timer on x-expires... in theory at least.
      @consumer = AMQP::Consumer.new(channel, queue, sid)
      @consumer.on_delivery do |metadata, payload|
        p [:get, sid, @consumer.consumer_tag, path, payload]
        metadata.ack
        block.call(payload)
      end.consume
    end

    def unsubscribe
      @consumer.cancel if @consumer
    end

    def ttl
      15000
    end

  protected
    def self.connection
      @connection ||= AMQP.connect
    end

    def self.sid
      SecureRandom.uuid
    end
  end
end