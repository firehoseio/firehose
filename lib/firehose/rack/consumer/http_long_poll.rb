require 'json'

module Firehose
  module Rack
    class Consumer
      class HttpLongPoll
        # How long should we wait before closing out the consuming clients web connection
        # for long polling? Most browsers timeout after a connection has been idle for 30s.
        TIMEOUT = 20

        attr_accessor :timeout

        def initialize(timeout=TIMEOUT)
          @timeout = timeout
          yield self if block_given?
        end

        def call(env)
          if Consumer.multiplexing_request?(env)
            MultiplexingHandler.new(@timeout).call(env)
          else
            DefaultHandler.new(@timeout).call(env)
          end
        end

        class Handler
          include Firehose::Rack::Helpers

          def initialize(timeout=TIMEOUT)
            @timeout = timeout
            yield self if block_given?
          end

          def call(env)
            request = request(env)
            method  = request.request_method

            case method
            # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
            # close down the requeust, and the client then reconnects.
            when "GET"
              handle_request(request, env)
              return ASYNC_RESPONSE
            # we use post messages for http long poll multiplexing
            when "POST"
              if Consumer.multiplexing_request?(env)
                handle_request(request, env)
                return ASYNC_RESPONSE
              end
            end

            Firehose.logger.debug "HTTP #{method} not supported"
            response(405, "#{method} not supported.", "Allow" => "GET")
          end

          private

          # If the request is a CORS request, return those headers, otherwise don't worry 'bout it
          def response_headers(env)
            cors_origin(env) ? cors_headers(env) : {}
          end

          def cors_origin(env)
            env['HTTP_ORIGIN']
          end

          def cors_headers(env)
            # TODO seperate out CORS logic as an async middleware with a Goliath web server.
            {'Access-Control-Allow-Origin' => cors_origin(env)}
          end

          def request(env)
            env['parsed_request'] ||= ::Rack::Request.new(env)
          end

          def async_callback(env, code, message = "", headers = nil)
            resp_headers = response_headers(env)

            if headers
              resp_headers.merge!(headers)
            end

            if cb = env["async.callback"]
              cb.call response(code, message, resp_headers)
            else
              Firehose.logger.error "async.callback not set for response: #{message.inspect}"
            end
          end

          def respond_async(channel, last_sequence, env)
            EM.next_tick do
              if last_sequence < 0
                async_callback env, 400, "The last_message_sequence parameter may not be less than zero"
              else
                Server::Channel.new(channel).next_message(last_sequence, :timeout => @timeout).callback do |message, sequence|
                  async_callback env, 200, wrap_frame(channel, message, sequence)
                end.errback do |e|
                  if e == :timeout
                    async_callback env, 204
                  else
                    Firehose.logger.error "Unexpected error when trying to GET last_sequence #{last_sequence} for path #{channel}: #{e.inspect}"
                    async_callback env, 500, "Unexpected error"
                  end
                end
              end
            end
          end
        end

        class DefaultHandler < Handler
          def wrap_frame(channel, message, last_sequence)
            JSON.generate :message => message, :last_sequence => last_sequence
          end

          def log_request(path, last_sequence, env)
            Firehose.logger.debug "HTTP GET with last_sequence #{last_sequence} for path #{path} with query #{env["QUERY_STRING"].inspect}"
          end

          def handle_request(request, env)
            # Get the Last Message Sequence from the query string.
            # Ideally we'd use an HTTP header, but android devices don't let us
            # set any HTTP headers for CORS requests.
            last_sequence = request.params['last_message_sequence'].to_i
            channel       = request.path

            log_request   channel, last_sequence, env
            respond_async channel, last_sequence, env
          end
        end

        class MultiplexingHandler < Handler
          def wrap_frame(channel, message, last_sequence)
            JSON.generate channel: channel, :message => message, :last_sequence => last_sequence
          end

          def log_request(request, subscriptions, env)
            if request.post?
              Firehose.logger.debug "HTTP multiplexing POST, subscribing #{subscriptions.inspect}"
            else
              Firehose.logger.debug "HTTP multiplexing GET with query #{env["QUERY_STRING"].inspect}"
            end
          end

          def handle_request(request, env)
            subscriptions = Consumer.multiplex_subscriptions(request)
            log_request request, subscriptions, env
            subscriptions.each do |sub|
              respond_async(sub[:channel], sub[:message_sequence], env)
            end
          end
        end
      end
    end
  end
end
