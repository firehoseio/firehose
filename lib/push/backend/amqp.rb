require 'amqp'

module Push::Backend
  # Asynchronously publish and subscribe to messages to AMQP with Em::AMQP gem.
  class AMQP
    include PubSub

    attr_reader :connection

    def initialize(connection=self.class.connection)
      @connection = connection
    end

    # Run this puppy inside of Em.
    def publish(message, name)
      channel.fanout(name, :auto_delete => true).publish(message)
    end

    # Setup the subscription
    def subscribe(subscription)
      # channel = channel(:prefetch => 1)
      queue = channel.queue("#{subscription.consumer.id}@#{subscription.channel}", :arguments => {'x-expires' => Push.config.amqp.queue_ttl * 1000})
      fanout = channel.fanout(subscription.channel, :auto_delete => true)

      subscription.on_delete { queue.delete }

      queue.bind(fanout, :ack => true).subscribe do |metadata, payload|
        metadata.ack
        subscription.process_message(payload)
      end
    end

  private
    # Create an instance of an AMQP channel
    def channel(opts={})
      # The prefetch tells AMQP that we only want to grab one message at most when we connect to the queue. This prevents
      # messages from being dropped or not ack'ed when the client comes back around to reconnect.
      @channel ||= ::AMQP::Channel.new(connection).prefetch(opts[:prefetch] || 1)
    end

    def self.connection
      @connection ||= ::AMQP.connect(Push.config.amqp.to_hash.merge(:logging => true).merge(:auto_recovery => true))
    end
  end
end