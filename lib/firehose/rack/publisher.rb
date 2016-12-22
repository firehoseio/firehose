require "rack/utils"

module Firehose
  module Rack
    class Publisher
      include Firehose::Rack::Helpers

      def call(env)
        req           = env['parsed_request'] ||= ::Rack::Request.new(env)
        path          = req.path
        method        = req.request_method
        cache_control = {}

        # Parse out cache control directives from the Cache-Control header.
        if cache_control_header = env['HTTP_CACHE_CONTROL']
          cache_control = cache_control_header.split(',').map(&:strip).inject({}) do |memo, directive|
            key, value = directive.split('=')
            memo[key.downcase] = value
            memo
          end
        end

        # Read the max-age directive from the cache so that we can set a TTL on the redis key. This will
        # prevent stale content from being served up to the client.
        ttl = cache_control['max-age']

        if method == 'PUT'
          EM.next_tick do
            body = env['rack.input'].read
            Firehose.logger.debug "HTTP published #{body.inspect} to #{path.inspect} with ttl #{ttl.inspect}"
            opts = { :ttl => ttl }.merge(parse_options(env))
            publisher.publish(path, body, opts).callback do
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

      def parse_options(env)
        opts = {}
        if buffer_size = env["HTTP_X_FIREHOSE_BUFFER_SIZE"]
          opts[:buffer_size] = buffer_size.to_i
        end
        if deprecated = env["HTTP_X_FIREHOSE_DEPRECATED"]
          opts[:deprecated] = deprecated == "true"
        end
        if persist = env["HTTP_X_FIREHOSE_PERSIST"]
          opts[:persist] = persist == "true"
        end
        opts
      end

      def publisher
        @publisher ||= Firehose::Server::Publisher.new
      end
    end
  end
end
