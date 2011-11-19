require 'amqp'

module Push
  # Backends for test and development environments
  module Backend
    # Mix this into backends that producers may push messages onto
    module Publishable
      # Publish a message into the backend
      def publish(*channels)
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
      def subscribe(*channels, &block)
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

    class Test
      include Push::Logging
      include PubSub

      def publish(message, *channels)
        channels.each do |name|
          logger.debug "Publishing '#{message}' to channel '#{name}'"
          channel[name] << message
        end
      end

      # Loop through everything until its all out of the array. The key here is not to block because
      # we want to test pubsub in a sync environment to keep things sane
      def subscribe(*channels, &block)
        channels.each do |name|
          until channel[name].empty? do
            message = channel[name].pop
            logger.debug "Consuming '#{message}' from channel '#{name}'"
            block.call message
          end
          # Kill the channel once all of the messages are out of it. This simulates the cleaning up
          # of a message exchange
          channel.delete name
        end
      end

      # The key of this hash corresponds to a channel on the backend. The value of the hash is an array
      # of messages on the channel.
      def channel
        @channel ||= Hash.new {|h,k| h[k] = []} # Default hash empty hash values with an array (instead of nil)
      end
    end

    class AMQP
      include Push::Logging

      def publish(message, exchange)
        EM.reactor_running? ? async_publish(message, exchange) : sync_publish(message, exchange)
        logger.debug "Published '#{message}' to exchange #{exchange}"
      end

      # Deal with running AMQP inside of a sync environment. This is useful
      # for script/console testing and our pe_result_processor.
      def sync_publish(message, exchange)
        Bunny.run(Push.config.amqp.to_hash) { |channel| 
          channel.exchange(exchange, :type => :fanout).publish(message)
        }
      end

      # Run this puppy inside of Em.
      def async_publish(message, exchange)
        channel = ::AMQP::Channel.new(connection)
        channel.fanout(exchange).publish(message)
        EM.next_tick {
          channel.close
          logger.debug "Channel closed"
        }
      end

      # Make sure we setup and use one connection per Push instance. AMQP 
      # wants to minimize connects/reconnects, so we connect once here and 
      # let publish use this connection.
      def connection
        @connection ||= ::AMQP.connect(Push.config.amqp.to_hash)
      end
    end

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
end