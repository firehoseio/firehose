require 'faye/websocket'
require 'json'

module Firehose
  module Rack
    class ConsumerApp
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
                env['async.callback'].call response(400, "Header '#{LAST_MESSAGE_SEQUENCE_HEADER}' may not be less than zero", response_headers(env))
              else
                Channel.new(path).next_message(last_sequence, :timeout => TIMEOUT).callback do |message, sequence|
                  env['async.callback'].call response(200, message, response_headers(env).merge(LAST_MESSAGE_SEQUENCE_HEADER => sequence.to_s))
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

        # If the request is a CORS request, return those headers, otherwise don't worry 'bout it
        def response_headers(env)
          cors_origin(env) ? cors_headers(env) : {}
        end

        def cors_origin(env)
          env['HTTP_ORIGIN']
        end

        def cors_headers(env)
          # TODO seperate out CORS logic as an async middleware with a Goliath web server.
          {
            'Access-Control-Allow-Origin'     => cors_origin(env),
            'Access-Control-Expose-Headers'   => LAST_MESSAGE_SEQUENCE_HEADER
          }
        end
      end


      # It _may_ be more memory efficient if we used the same instance of this
      # class (or even if we just used a proc/lambda) for every
      # request/connection. However, we couldn't use instance variables, and
      # so I'd need to confirm that local variables would be accessible from
      # the callback blocks.
      class WebSocket
        def call(env)
          req   = ::Rack::Request.new(env)
          @path  = req.path
          ws = Faye::WebSocket.new(env)

          ws.onopen = lambda do |event|
            Firehose.logger.debug "WS subscribed to `#{@path}`"

            subscribe = Proc.new do |last_sequence|
              @channel = Channel.new(@path)
              @deferrable = @channel.next_message(last_sequence).callback do |message, sequence|
                Firehose.logger.debug "WS sent `#{message}` to `#{@path}` with sequence `#{sequence}`"
                ws.send message
                subscribe.call(sequence)
              end.errback { |e| EM.next_tick { raise e.inspect } unless e == :disconnect }
            end

            subscribe.call nil
          end

          ws.onmessage = lambda do |event|
            STDERR.puts "WS message received => #{event.data.inspect}"
            #!=!#
            o = JSON.parse(event.data, :symbolize_names => true) rescue {}
            ws.send(JSON.generate(:pong => 'PONG')) if o[:ping] == 'PING'
          end

          ws.onclose = lambda do |event|
            if @deferrable
              @deferrable.fail :disconnect
              @channel.unsubscribe(@deferrable) if @channel
            end
            Firehose.logger.debug "WS connection `#{@path}` closing. Code: #{event.code.inspect}; Reason #{event.reason.inspect}"
          end

          ws.onerror = lambda do |event|
            Firehose.logger.error "WS connection `#{@path}` error `#{error}`: #{error.backtrace}"
          end


          # Return async Rack response
          ws.rack_response
        end
      end
    end
  end
end
