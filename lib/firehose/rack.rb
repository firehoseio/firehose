module Firehose
  module Rack
    autoload :Consumer,   'firehose/rack/consumer'
    autoload :Publisher,  'firehose/rack/publisher'
    autoload :Ping,       'firehose/rack/ping'
    autoload :App,        'firehose/rack/app'
    autoload :MetricsAPI, 'firehose/rack/metrics_api'

    # Evented web servers recognize the -1 HTTP code as a response deferral, which
    # is needed to stream responses via WebSockets or HTTP long polling.
    ASYNC_RESPONSE = [-1, {}, []].freeze

    # Normally we'd want to use a custom header to reduce the likelihood of some
    # HTTP middleware clobbering the value. But Safari seems to ignore our CORS
    # header instructions, so we are using 'pragma' because it is always allowed.
    LAST_MESSAGE_SEQUENCE_HEADER = 'Pragma'

    # Rack wants the header to start with HTTP, so we deal with that here.
    RACK_LAST_MESSAGE_SEQUENCE_HEADER = "HTTP_#{LAST_MESSAGE_SEQUENCE_HEADER.upcase.gsub('-', '_')}"

    # Disable CORS preflight caches for requests in development mode.
    CORS_OPTIONS_MAX_AGE = ENV['RACK_ENV'] == 'development' ? '1' : '1728000'

    module Helpers
      # Calculates the content of a message body for the response so that HTTP Keep-Alive
      # connections work.
      def response(status, body='', headers={})
        headers = {'Content-Length' => body.bytesize.to_s}.merge(headers)
        [status, headers, [body]]
      end

      # If the request is a CORS request, return those headers, otherwise don't worry 'bout it
      def response_headers(env, merge_headers={})
        headers = cors_origin(env) ? cors_headers(env) : {}
        headers.merge(merge_headers)
      end

      def cors_origin(env)
        env['HTTP_ORIGIN']
      end

      def cors_headers(env)
        {'Access-Control-Allow-Origin' => cors_origin(env)}
      end
    end
  end
end
