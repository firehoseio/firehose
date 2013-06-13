require 'faye/websocket'
require 'json'

module Firehose
  module Rack
    # Handles a subscription request over HTTP or WebSockets depeding on its abilities and
    # binds that to the Firehose::Server::Subscription class, which is bound to a channel that
    # gets published to.
    class Consumer
      def call(env)
        websocket_request?(env) ? websocket.call(env) : http_long_poll.call(env)
      end

      private
      def websocket
        WebSocket.new
      end

      def http_long_poll
        @http_long_poll ||= HttpLongPoll.new
      end

      def websocket_request?(env)
        Faye::WebSocket.websocket?(env)
      end

      class HttpLongPoll
        include Firehose::Rack::Helpers

        # How long should we wait before closing out the consuming clients web connection
        # for long polling? Most browsers timeout after a connection has been idle for 30s.
        TIMEOUT = 20

        def call(env)
          req     = env['parsed_request'] ||= ::Rack::Request.new(env)
          path    = req.path
          method  = req.request_method
          # Get the Last Message Sequence from the query string.
          # Ideally we'd use an HTTP header, but android devices don't let us
          # set any HTTP headers for CORS requests.
          last_sequence = req.params['last_message_sequence'].to_i

          case method
          # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
          # close down the requeust, and the client then reconnects.
          when 'GET'
            Firehose.logger.debug "HTTP GET with last_sequence #{last_sequence} for path #{path} with query #{env["QUERY_STRING"].inspect} and params #{req.params.inspect}"
            EM.next_tick do

              if last_sequence < 0
                env['async.callback'].call response(400, "The last_message_sequence parameter may not be less than zero", response_headers(env))
              else
                Server::Channel.new(path).next_message(last_sequence, :timeout => TIMEOUT).callback do |message, sequence|
                  env['async.callback'].call response(200, wrap_frame(message, sequence), response_headers(env))
                end.errback do |e|
                  if e == :timeout
                    env['async.callback'].call response(204, '', response_headers(env))
                  else
                    Firehose.logger.error "Unexpected error when trying to GET last_sequence #{last_sequence} for path #{path}: #{e.inspect}"
                    env['async.callback'].call response(500, 'Unexpected error', response_headers(env))
                  end
                end
              end

            end

            # Tell the web server that this will be an async response.
            ASYNC_RESPONSE

          else
            Firehose.logger.debug "HTTP #{method} not supported"
            response(501, "#{method} not supported.")
          end
        end


        private

        def wrap_frame(message, last_sequence)
          JSON.generate :message => message, :last_sequence => last_sequence
        end

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
      end


      # It _may_ be more memory efficient if we used the same instance of
      # this class (or if we even just used a lambda) for every connection.
      class WebSocket
        def call(env)
          req   = ::Rack::Request.new env
          @ws   = Faye::WebSocket.new env
          @path = req.path
          @ws.onopen    = method :handle_open
          @ws.onclose   = method :handle_close
          @ws.onerror   = method :handle_error
          @ws.onmessage = method :handle_message
          return @ws.rack_response
        end

        private
        def subscribe(last_sequence)
          @subscribed = true
          @channel    = Server::Channel.new @path
          @deferrable = @channel.next_message last_sequence
          @deferrable.callback do |message, sequence|
            Firehose.logger.debug "WS sent `#{message}` to `#{@path}` with sequence `#{sequence}`"
            @ws.send self.class.wrap_frame(message, last_sequence)
            subscribe sequence
          end
          @deferrable.errback do |e|
            EM.next_tick { raise e.inspect } unless e == :disconnect
          end
        end

        def handle_message(event)
          msg = JSON.parse(event.data, :symbolize_names => true) rescue {}
          seq = msg[:message_sequence]
          if msg[:ping] == 'PING'
            Firehose.logger.debug "WS ping received, sending pong"
            @ws.send JSON.generate :pong => 'PONG'
          elsif !@subscribed && seq.kind_of?(Integer)
            Firehose.logger.debug "Subscribing at message_sequence #{seq}"
            subscribe seq
          end
        end

        def handle_open(event)
          Firehose.logger.debug "WebSocket subscribed to `#{@path}`. Waiting for message_sequence..."
        end

        def handle_close(event)
          if @deferrable
            @deferrable.fail :disconnect
            @channel.unsubscribe(@deferrable) if @channel
          end
          Firehose.logger.debug "WS connection `#{@path}` closing. Code: #{event.code.inspect}; Reason #{event.reason.inspect}"
        end

        def handle_error(event)
          Firehose.logger.error "WS connection `#{@path}` error `#{event.inspect}`"
        end

        def self.wrap_frame(message, last_sequence)
          JSON.generate :message => message, :last_sequence => last_sequence
        end
      end

    end
  end
end
