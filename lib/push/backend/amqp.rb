require 'amqp'

module Push::Backend
  # Asynchronously publish and subscribe to messages to AMQP with Em::AMQP gem.
  class AMQP
    include PubSub
    include Push::Logging

    attr_reader :connection

    def initialize(connection=self.class.connection)
      @connection = connection
    end

    # Publish a message to an AMQP fanout queue.
    def publish(message, name)
      logger.debug "AMQP publishing `#{message}` to exchange `#{name}`"
      channel.fanout(name, :auto_delete => true).publish(message)
    end

    # Setup a queue for the consumer, then bind that queue to the fanout exchange created by the publisher.
    def subscribe(subscription)
      consumer_queue = "#{subscription.consumer.id}@#{subscription.channel}"
      queue = channel.queue(consumer_queue, :arguments => {'x-expires' => Push.config.amqp.queue_ttl * 1000})
      fanout = channel.fanout(subscription.channel, :auto_delete => true)

      subscription.on_delete {
        logger.debug "AMQP unbinding `#{consumer_queue}`"
        queue.unsubscribe
      }

      logger.debug "AMQP binding `#{consumer_queue}` to exchange `#{subscription.channel}`"
      queue.bind(fanout).subscribe(:ack => true) do |metadata, payload|
        logger.debug "AMQP acking payload `#{payload}`"
        metadata.ack
        subscription.process_message(payload)
      end
    end

  private
    # Create an instance of an AMQP channel
    def channel
      # The prefetch tells AMQP that we only want to grab one message at most when we connect to the queue. This prevents
      # messages from being dropped or not ack'ed when the client comes back around to reconnect.
      ::AMQP::Channel.new(connection).prefetch(1)
    end

    # Access and memoize the connection that we'll use for the AMQP backend
    def self.connection
      @connection ||= ::AMQP.connect(Push.config.amqp.to_hash.merge(:logging => true).merge(:auto_recovery => true))
    end
  end
end