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
      publish_channel.fanout(name, :auto_delete => true).publish(message)
    end

    # Setup a queue for the consumer, then bind that queue to the fanout exchange created by the publisher.
    def subscribe(subscription)
      consumer_queue = "#{subscription.consumer.id}@#{subscription.channel}"
      queue = subscription_channel.queue(consumer_queue, :arguments => {'x-expires' => Push.config.amqp.queue_ttl * 1000})
      fanout = subscription_channel.fanout(subscription.channel, :auto_delete => true)

      subscription.on_delete {
        logger.debug "AMQP unbinding `#{consumer_queue}`"
        # The AMQP server automatically deletes and unbinds this queue after the
        # number of seconds specified in the 'x-expires' argument above.
      }

      logger.debug "AMQP binding `#{consumer_queue}` to exchange `#{subscription.channel}`"
      queue.bind(fanout).subscribe(:ack => true) do |metadata, payload|
        logger.debug "AMQP acking payload `#{payload}`"
        metadata.ack
        subscription.process_message(payload)
      end

      # Install signal handlers to deal with cleaning up potentially long running
      # connections when we kill the server for reboots, etc.
      Signal.trap('TERM'){ subscription.delete }
    end

  private
    # We only need one channel to publish messages
    def publish_channel
      @publish_channel ||= ::AMQP::Channel.new(connection)
    end

    # If we keep our consumers in order, we only need one subscription channel
    # with a prefetch of 1 (prevent in-flight messages from getting lost).
    def subscription_channel
      @subscription_channel ||= ::AMQP::Channel.new(connection).prefetch(1)
    end

    # Access and memoize the connection that we'll use for the AMQP backend
    def self.connection
      ::AMQP.connect(Push.config.amqp.to_hash.merge(:logging => true).merge(:auto_recovery => true))
    end
  end
end