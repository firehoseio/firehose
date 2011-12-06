module Push
  # Give us a really easy way to subscribe messages to an MQ exchange. This is 
  # MQ agnostic so that it works in a test environment. Also, this Consumer will
  # generate or put into context Session IDs as needed that our backends can deal
  # with to maintain state between reconnects.
  class Consumer
    attr_accessor :id

    def initialize(id=nil,&block)
      @id = id
      block.call self if block
    end

    # Subscribe to the backend to configure an instance of a subscription, 
    # receive messages.
    def subscribe(channel, &block)
      subscription(channel){|s| s.on_message &block }.subscribe
    end
    alias :subscribe_to :subscribe

    def subscription(channel, &block)
      Subscription.new(self, channel, &block)
    end

    def id
      @id ||= self.class.random_id
    end

    # Generate a random ID for the consumer if one is not given to us.
    def self.random_id
      "#{Time.now.to_i}-#{rand(0xffffffffffff).to_i}"
    end
  end

  # Manages a subscription for a consumer. This class has methods that 
  # always get called by the consumer that make sure backend resources get
  # cleaned up, etc. (like releasing AMQP connections, etc.)
  class Consumer::Subscription
    attr_reader :backend, :consumer, :channel

    include Backend::Adapter
    include Push::Logging

    def initialize(consumer, channel, backend=self.class.backend, &block)
      @consumer, @channel, @backend = consumer, channel, backend
      block.call self if block
    end

    # Pass the subscription class into the backend
    def subscribe
      logger.debug "Subscription created for consumer `#{consumer.id}` to `#{channel}`"
      backend.subscribe(self)
      self
    end

    # Delete queue resources
    def delete
      logger.debug "Subscription deleted for consumer `#{consumer.id}` on `#{channel}`"
      on_delete.call(self) if on_delete
      self
    end

    # Run a message through the callback
    def process_message(message)
      logger.debug "Subscription message for consumer `#{consumer.id}` on `#{channel}`"
      on_message.call(message, self) if on_message
    end

    # Configure a callback to handle subscription deletions. Useful if there's
    # resources that need to be cleaned up, like a connection.
    def on_delete(&block)
      block ? @on_delete = block : @on_delete
    end

    # Run this when we process a message
    def on_message(&block)
      block ? @on_message = block : @on_message
    end

    # Instanciate and subscribe to a subscription via the backend
    def self.subscribe(*args, &block)
      subscription = new(*args, &block)
      subscription.subscribe
      subscription
    end
  end
end