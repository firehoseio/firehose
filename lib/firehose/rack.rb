require 'rack/websocket'

module Firehose
  module Rack
    AsyncResponse = [-1, {}, []]

    class HttpLongPoll
      def call(env)
        req     = ::Rack::Request.new(env)
        cid     = req.params['cid']
        path    = req.path
        method  = req.request_method
        timeout = 30
        cors_origin = env['HTTP_ORIGIN']
        cors_headers  = {
          'Access-Control-Allow-Origin'     => cors_origin,
          'Access-Control-Allow-Methods'    => 'GET',
          'Access-Control-Max-Age'          => '1728000',
          'Access-Control-Allow-Headers'    => 'Content-Type, User-Agent, If-Modified-Since, Cache-Control'
        }

        case method
        # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
        # close down the requeust, and the client then reconnects.
        when 'GET'
          EM.next_tick do
            # If the request is a CORS request, return those headers, otherwise don't worry 'bout it
            response_headers = cors_origin ? cors_headers : {}

            # Setup a subscription with a client id. We haven't subscribed yet here.
            subscription = Firehose::Subscription.new(cid)

            # Setup a timeout timer to tell clients that time out that everything is OK
            # and they should come back for more
            timer = EventMachine::Timer.new(timeout) do
              # We send a 204 OK to tell the client to reconnect.
              env['async.callback'].call [204, response_headers, []]
              Firehose.logger.debug "HTTP wait `#{cid}@#{path}` timed out"
            end

            # Ok, now subscribe to the subscription.
            subscription.subscribe path do |message|
              timer.cancel # Turn off the heart beat so we don't execute any of that business.
              subscription.unsubscribe
              subscription = nil # Set this to nil so that our heart beat timer doesn't try to double unsub.
              env['async.callback'].call [200, response_headers, [message]]
              Firehose.logger.debug "HTTP sent `#{message}` to `#{cid}@#{path}`"
            end
            Firehose.logger.debug "HTTP subscribed to `#{cid}@#{path}`"

            # Unsubscribe from the subscription if its still open and something bad happened
            # or the heart beat triggered before we could finish.
            env['async.close'].callback do
              subscription.unsubscribe if subscription
              Firehose.logger.debug "HTTP connection `#{cid}@#{path}` closing"
            end
          end

          # Tell the web server that this will be an async response.
          Firehose::Rack::AsyncResponse

        # PUT is how we throw messages on to the fan-out queue.
        when 'PUT'
          body = env['rack.input'].read
          Firehose.logger.debug "HTTP published `#{body}` to `#{path}`"
          Firehose::Publisher.new.publish(path, body)

          [202, {}, []]
        else
          Firehose.logger.debug "HTTP #{method} not supported"
          [501, {'Content-Type' => 'text/plain'}, ["#{method} not supported."]]
        end
      end
    end

    class WebSocket < ::Rack::WebSocket::Application
      attr_reader :cid, :path
      
      # Subscribe to a path and make some magic happen, mmkmay?
      def on_open(env)
        req   = ::Rack::Request.new(env)
        @cid   = req.params['cid']
        @path  = req.path

        @subscription = Firehose::Subscription.new(cid)
        @subscription.subscribe path do |message|
          Firehose.logger.debug "WS sent `#{message}` to `#{cid}@#{path}`"
          send_data message
        end
        Firehose.logger.debug "WS subscribed to `#{cid}@#{path}`"
      end

      # Delete the subscription if the thing even happened.
      def on_close(env)
        @subscription.unsubscribe if @subscription
        Firehose.logger.debug "WS connection `#{cid}@#{path}` closing"
      end

      # Log websocket level errors
      def on_error(env, error)
        Firehose.logger.error "WS connection `#{cid}@#{path}` error `#{error}`: #{env.inspect}"
        @subscription.unsubscribe if @subscription
      end
    end

    class App
      def call(env)
        websocket_request?(env) ? websocket.call(env) : http_long_poll.call(env)
      end

    private
      def websocket
        @websocket ||= WebSocket.new
      end

      def http_long_poll
        @http_long_poll ||= HttpLongPoll.new
      end

      def websocket_request?(env)
        env['HTTP_UPGRADE'] =~ /websocket/i
      end
    end
  end
end