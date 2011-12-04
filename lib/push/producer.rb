module Push
  # Give us a really easy way to publish messages to an MQ channel. This is 
  # MQ agnostic so that it works in a test environment.
  class Producer
    attr_reader :backend
    
    include Backend::Adapter

    # This gives us a nice Push.publish(message).to(channel) DSL.
    class DSL
      include Push::Logging

      def initialize(backend, message)
        @backend, @message = backend, message
      end

      def to(channel)
        logger.debug "Publishing `#{@message}` to `#{channel}`"
        @backend.publish(@message, channel)
      end
    end

    def initialize(backend=self.class.backend)
      @backend = backend
    end

    def publish(message)
      DSL.new(backend, message)
    end
  end
end