require 'bunny'

module Push::Backend
  # Synchronously publish and subscribe to messages to AMQP with the Bunny AMQP gem.
  class Bunny
    include PubSub
    include Push::Logging

    attr_reader :connection

    def initialize(connection=self.class.connection)
      @connection = connection
    end

    # Publish a message to the fanout exchange.
    def publish(message, name)
      logger.debug "Bunny publishing `#{message}` to exchange `#{name}`"
      connection.exchange(name, :auto_delete => true, :type => :fanout).publish(message)
    end

    # Setup the propper resource management around 
    def subscribe(subscription)
      queue = connection.queue "#{subscription.consumer.id}@#{subscription.channel}",
        :auto_delete  => true,
        :arguments    => {'x-expires' => Push.config.amqp.queue_ttl * 1000}
      fanout = connection.exchange(subscription.channel, :auto_delete => true, :type => :fanout)
      queue.bind(fanout)

      # Cleanup is handled automatically for us by the timeout that we set on the 
      # client connection queue. There's also no channel clean-up since we're not 
      # running this inside of a concurrent run-time environment.

      # Try popping a message off the queue, deal with Bunny idiosyncracies, and 
      # pass the message into the subscription object for further processing.
      subscription.process_message(self.class.process_message(queue.pop))
    end

  private
    # Clean up and normalize Bunny messages into something that Push can pass onto
    # the consumer.
    def self.process_message(message)
      message[:payload] == :queue_empty ? nil : message[:payload]
    end

    # Default connection for Bunny AMPQ connection
    def self.connection
      unless @connection
        @connection = ::Bunny.new(Push.config.amqp)
        @connection.start
      end
      @connection
    end
  end
end