require 'amqp'

module Push
  # Backends for test and development environments
  module Backend
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

    class Test
      include Push::Logging
      
      def publish(message, exchange_name)
        logger.debug "Published '#{message}' to exchange #{exchange}"
        exchange[exchange_name] << message
      end

      def exchange
        @exchange ||= Hash.new {|h,k| h[k] = []} # Default hash empty hash values with an array (instead of nil)
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