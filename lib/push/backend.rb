require 'amqp'
require 'bunny'

module Push
  # Backends for test and development environments
  module Backend
    autoload :Test,   'push/backend/test'
    autoload :AMQP,   'push/backend/amqp'
    autoload :Bunny,  'push/backend/bunny'

    # Mix this into backends that producers may push messages onto
    module Publishable
      # Publish a message into the backend
      def publish(channel)
      end

      # Introspection to see if this backend can be published to
      def publishable?
        true
      end
    end

    # Mix this into backends that consumers may subscribe to for messages
    module Subscribable
      # Subscribe to a channel, then wait to receive messages on it. This
      # call is usually async, otherwise it will block.
      def subscribe(consumer, channel, &block)
      end

      # Cleans up subscription connections, etc.
      def unsubscribe(&block)
        block.call(self)
      end

      # Introspection to see if this backend can be subscribed to
      def subscribable?
        true
      end
    end

    # Messages can be both published or subscribed to this backend
    module PubSub
      def self.included(klass)
        klass.send(:include, Subscribable)
        klass.send(:include, Publishable)
      end
    end

    # Lets make this inheritable if people perfer that.
    class Base
      include PubSub
    end

    # Now we need to make adapters registerable so that folks can set these in their configuration
    # file settings
    def self.register_adapter(name, adapter)
      adapters[name.to_sym] = adapter
    end

    def self.adapter(name=Push.config.backend)
      adapters[name.to_sym].new
    end

    def self.adapters
      @adapters ||= {}
    end
  end

  Backend.register_adapter :bunny,  Backend::Bunny
  Backend.register_adapter :amqp,   Backend::AMQP
  Backend.register_adapter :test,   Backend::Test
end