module Firehose
  module Rack
    autoload :Consumer,    'firehose/rack/consumer'
    autoload :Publisher,   'firehose/rack/publisher'
    autoload :Ping,        'firehose/rack/ping'

    # Evented web servers recognize this as a response deferral.
    ASYNC_RESPONSE = [-1, {}, []].freeze

    # Normally we'd want to use a custom header to reduce the likelihood of some
    # HTTP middleware clobbering the value. But Safari seems to ignore our CORS
    # header instructions, so we are using 'pragma' because it is always allowed.
    LAST_MESSAGE_SEQUENCE_HEADER = 'Pragma'
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

        case method
        when 'PUT'
          publisher.call(env)
        when 'HEAD'
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

    module Helpers
      # Calculates the content length for you
      def response(status, body='', headers={})
        headers = {'Content-Length' => body.size.to_s}.merge(headers)
        [status, headers, [body]]
      end
    end
  end
end
