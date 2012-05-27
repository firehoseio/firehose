require 'rack/websocket'

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
        env['HTTP_UPGRADE'] =~ /websocket/i
      end

      class HttpLongPoll
        # Evented web servers recognize this as a response deferral.
        ASYNC_RESPONSE = [-1, {}, []].freeze

        # How long should we wait before closing out the consuming clients web connection 
        # for long polling? Most browsers timeout after a connection has been idle for 30s.
        TIMEOUT = 20

        def call(env)
          req     = env['parsed_request'] ||= ::Rack::Request.new(env)
          path    = req.path
          method  = req.request_method
          last_sequence = env[RACK_LAST_MESSAGE_SEQUENCE_HEADER].to_i
          cors_origin = env['HTTP_ORIGIN']

          case method
          # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
          # close down the requeust, and the client then reconnects.
          when 'GET'
            EM.next_tick do
              # TODO seperate out CORS logic as an async middleware with a Goliath web server.
              cors_headers  = {
                'Access-Control-Allow-Origin'     => cors_origin,
                'Access-Control-Expose-Headers'   => LAST_MESSAGE_SEQUENCE_HEADER
              }

              # If the request is a CORS request, return those headers, otherwise don't worry 'bout it
              response_headers = cors_origin ? cors_headers : {}

              if last_sequence < 0
                env['async.callback'].call [400, response_headers, ["Header '#{LAST_MESSAGE_SEQUENCE_HEADER}' may not be less than zero"]]
              else
                Channel.new(path).next_message(last_sequence, :timeout => TIMEOUT).callback do |message, sequence|
                  response_headers.merge!(LAST_MESSAGE_SEQUENCE_HEADER => sequence.to_s)
                  env['async.callback'].call [200, response_headers, [message]]
                end.errback do |e|
                  if e == :timeout
                    env['async.callback'].call [204, response_headers, []]
                  else
                    raise e
                  end
                end
              end
            end

            # Tell the web server that this will be an async response.
            ASYNC_RESPONSE

          # Tell the browser that we're cool about shipping Last-Message-Sequence headers back-and-forth.
          when 'OPTIONS'
            # TODO seperate out CORS logic as an async middleware with a Goliath web server.
            [200, {
            'Access-Control-Allow-Methods'    => 'GET',
            'Access-Control-Allow-Origin'     => cors_origin,
            'Access-Control-Allow-Headers'    => LAST_MESSAGE_SEQUENCE_HEADER,
            'Access-Control-Expose-Headers'   => LAST_MESSAGE_SEQUENCE_HEADER,
            'Access-Control-Max-Age'          => '1728000'
            }, []]
          else
            Firehose.logger.debug "HTTP #{method} not supported"
            [501, {'Content-Type' => 'text/plain'}, ["#{method} not supported."]]
          end
        end
      end


      class WebSocket < ::Rack::WebSocket::Application
        attr_reader :path, :subscription

        # Subscribe to a path and make some magic happen, mmkmay?
        def on_open(env)
          req   = ::Rack::Request.new(env)
          @path  = req.path

          Firehose.logger.debug "WS subscribed to `#{path}`"

          subscribe = Proc.new do |last_sequence|
            @channel = Channel.new(path)
            @deferrable = @channel.next_message(last_sequence).callback do |message, sequence|
              Firehose.logger.debug "WS sent `#{message}` to `#{path}` with sequence `#{sequence}`"
              send_data message
              subscribe.call(sequence)
            end.errback { |e| raise e.inspect unless e == :disconnect }
          end

          subscribe.call
        end

        # Delete the subscription if the thing even happened.
        def on_close(env)
          if @deferrable
            @deferrable.fail :disconnect
            @channel.unsubscribe(@deferrable) if @channel
          end
          Firehose.logger.debug "WS connection `#{path}` closing"
        end

        # Log websocket level errors
        def on_error(env, error)
          Firehose.logger.error "WS connection `#{path}` error `#{error}`: #{error.backtrace}"
        end
      end
    end
  end
end
