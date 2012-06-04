module Firehose
  module Rack
    autoload :ConsumerApp,    'firehose/rack/consumer_app'
    autoload :PublisherApp,   'firehose/rack/publisher_app'

    # Normally we'd want to use a custom header to reduce the likelihood of some
    # HTTP middleware clobbering the value. But Safari seems to ignore our CORS
    # header instructions, so we are using 'pragma' because it is always allowed.
    LAST_MESSAGE_SEQUENCE_HEADER = 'pragma'
    RACK_LAST_MESSAGE_SEQUENCE_HEADER = "HTTP_#{LAST_MESSAGE_SEQUENCE_HEADER.upcase.gsub('-', '_')}"
    # Don't cache in development mode
    CORS_OPTIONS_MAX_AGE = ENV['RACK_ENV'] == 'development' ? '1' : '1728000'

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
