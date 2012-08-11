module Firehose
  module Rack
    class PublisherApp
      include Firehose::Rack::Helpers

      def call(env)
        req     = env['parsed_request'] ||= ::Rack::Request.new(env)
        path    = req.path
        method  = req.request_method
        cache_control = {}

        # Parse out cache control directives from the Cache-Control header.
        if cache_control_header = env['Cache-Control']
          cache_control = cache_control_header.split(',').map(&:strip).inject({}) do |memo, directive|
            key, value = directive.split('=')
            memo[key.downcase] = value
            memo
          end
        end

        if method == 'PUT'
          EM.next_tick do
            body = env['rack.input'].read
            Firehose.logger.debug "HTTP published `#{body}` to `#{path}`"
            publisher.publish(path, body, :ttl => cache_control['max-age']).callback do
              env['async.callback'].call [202, {'Content-Type' => 'text/plain', 'Content-Length' => '0'}, []]
              env['async.callback'].call response(202, '', 'Content-Type' => 'text/plain')
            end.errback do |e|
              Firehose.logger.debug "Error publishing: #{e.inspect}"
              env['async.callback'].call response(500, 'Error when trying to publish', 'Content-Type' => 'text/plain')
            end
          end

          # Tell the web server that this will be an async response.
          ASYNC_RESPONSE
        else
          Firehose.logger.debug "HTTP #{method} not supported"
          msg = "#{method} not supported."
          [501, {'Content-Type' => 'text/plain', 'Content-Length' => msg.size.to_s}, [msg]]
        end
      end

    private
      def publisher
        @publisher ||= Firehose::Publisher.new
      end
    end
  end
end
