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
            pubs = publications(path, env)
            publish(pubs, env).callback do
              env['async.callback'].call response(202, '', 'Content-Type' => 'text/plain')
            end.errback do |e|
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

      def publications(path, env)
        body = env['rack.input'].read

        if multiplexing_request?(env)
          Publication.from_json(body)
        else
          [Publication.from_request(path, body, env)]
        end
      end

      class Publication < Struct.new(:channel, :payload, :buffer_size, :ttl, :deprecated, :persist, :deferrable)
        def self.from_json(json_str)
          pubs = JSON.parse(json_str)
          case pubs
          when Array
            pubs.map do |p|
              Publication.from_hash(p)
            end
          when Hash
            Publication.from_hash(pubs)
          else
            raise ArgumentError.new("Invalid message to be published: #{pubs.inspect}")
          end
        end

        def self.from_hash(h)
          Publication.new(
            h["channel"],
            h["payload"],
            h["buffer_size"],
            h["ttl"],
            h["deprecated"],
            h["persist"]
          )
        end

        def self.from_request(path, body, env)
          p = Publication.new(path, body).parse_options(env)
        end

        def parse_options(env)
          if buffer_size = env["HTTP_X_FIREHOSE_BUFFER_SIZE"]
            self.buffer_size = buffer_size.to_i
          end
          if deprecated = env["HTTP_X_FIREHOSE_DEPRECATED"]
            self.deprecated = deprecated == "true"
          end
          if persist = env["HTTP_X_FIREHOSE_PERSIST"]
            self.persist = persist == "true"
          end
          self
        end
      end

      def publish(pubs, env)
        d =
          case pubs
          when Array
            publisher.publish_all(pubs)
          when Publication
            publisher.publish(pubs)
          end

        d.callback do
          case pubs
          when Array
            pubs.each { |p| log_published(p) }
          when Publication
            log_published(pubs)
          end
        end.errback do |e|
          Firehose.logger.debug "Error publishing: #{e.inspect}"
        end
      end

      def log_published(pub)
        Firehose.logger.debug "HTTP published #{pub.payload.inspect} to #{pub.channel.inspect} with ttl #{pub.ttl.inspect}"
      end

      def publisher
        @publisher ||= Firehose::Server::Publisher.new
      end
    end
  end
end
