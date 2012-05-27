module Firehose
  module Rack
    autoload :ConsumerApp,    'firehose/rack/consumer_app'
    autoload :PublisherApp,   'firehose/rack/publisher_app'

    LAST_MESSAGE_SEQUENCE_HEADER = 'Last-Message-Sequence'
    RACK_LAST_MESSAGE_SEQUENCE_HEADER = "HTTP_#{LAST_MESSAGE_SEQUENCE_HEADER.upcase.gsub('-', '_')}"

    # Allows the publisher and consumer to be mounted on the same port.
    class App
      def call(env)
        # Cache the parsed request so we don't need to re-parse it when we pass
        # control onto another app.
        req     = env['parsed_request'] ||= ::Rack::Request.new(env)
        method  = req.request_method

        if method == 'PUT'
          publisher.call(env)
        else
          consumer.call(env)
        end
      end


      private
      def publisher
        @publisher ||= PublisherApp.new
      end

      def consumer
        @consumer ||= ConsumerApp.new
      end
    end
  end
end
