module Firehose
  module Rack
    # Allows the publisher and consumer to be mounted on the same port.
    class App
      def call(env)
        # Cache the parsed request so we don't need to re-parse it when we pass
        # control onto another app.
        req     = env['parsed_request'] ||= ::Rack::Request.new(env)
        method  = req.request_method

        case method
        when 'PUT'
          # Firehose::Client::Publisher PUT's payloads to the server.
          publisher.call(env)
        when 'HEAD' 
          # HEAD requests are used to prevent sockets from timing out
          # from inactivity
          ping.call(env)
        else
          consumer.call(env)
        end
      end

    private
      def publisher
        @publisher ||= Publisher.new
      end

      def consumer
        @consumer ||= Consumer.new
      end

      def ping
        @ping ||= Ping.new
      end
    end
  end
end