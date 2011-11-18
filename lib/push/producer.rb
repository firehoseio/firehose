module Push
  # Give us a really easy way to publish messages to an MQ exchange. This is 
  # MQ agnostic so that it works in a test environment.
  class Producer
    attr_reader :backend
    
    # This gives us a nice Push.publish(message).to(exchange) DSL.
    class DSL
      def initialize(backend, message)
        @backend, @message = backend, message
      end

      def to(exchange)
        @backend.publish(@message, exchange)
      end
    end

    def initialize
      @backend = Backend.adapter
    end

    def publish(message)
      DSL.new(backend, message)
    end
  end
end