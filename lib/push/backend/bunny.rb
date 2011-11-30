require 'bunny'

module Push::Backend
  # Synchronously publish and subscribe to messages to AMQP with the Bunny AMQP gem.
  class Bunny
    include PubSub

    attr_reader :consumer

    def publish(message, name)
      exchange(name).publish(message)
    end

    def subscribe(consumer, name, &block)
      @consumer = consumer
      message = consumer_queue(name).pop
      block.call(message[:payload] == :queue_empty ? nil : message[:payload])
    end

    # Unsubscribe from the queue, unbind the thing, and crush it!
    def unsubscribe
      if @consumer_queue
        @consumer_queue.unsubscribe
        @consumer_queue = nil
      end
    end

  private
    # Create an instance of an exchange
    def exchange(name)
      connection.exchange(name, :auto_delete => true, :type => :fanout)
    end

    # Create a queue that the consumer uses to pop messages off this thing.
    def consumer_queue(name)
      unless @consumer_queue
        @consumer_queue = connection.queue("#{consumer.id}@#{name}", :auto_delete => true, :arguments => {'x-expires' => Push.config.amqp.queue_ttl * 1000})
        @consumer_queue.bind(exchange(name))
      end
      @consumer_queue
    end

    def self.connection
      unless @connection
        @connection = ::Bunny.new(Push.config.amqp)
        @connection.start
      end
      @connection
    end

    def connection
      @connection ||= self.class.connection
    end
  end
end