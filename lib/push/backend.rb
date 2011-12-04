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

    # Provide interface from both the Consumer and Producer to 
    # obtain a backend adapter for use when publishing or subscribing 
    # to messages
    module Adapter
      def self.included(base)
        base.send(:extend, ClassMethods)
      end

      module ClassMethods
        # Memoize the default backend adapter
        def backend
          @backend ||= Backend::Adapters.adapter
        end

        # Override the default backend adapter. This is insanely
        # useful for testing specific backends
        def backend=(backend)
          @backend = backend
        end
      end
    end

    module Adapters
      # Now we need to make adapters registerable so that folks can set these in their configuration
      # file settings
      def self.register(name, adapter)
        adapters[name.to_sym] = adapter
      end

      def self.adapter(name=Push.config.backend)
        adapters[name.to_sym].new
      end

      def self.adapters
        @adapters ||= {}
      end
    end
  end

  Backend::Adapters.register :bunny,  Backend::Bunny
  Backend::Adapters.register :amqp,   Backend::AMQP
  Backend::Adapters.register :test,   Backend::Test
end