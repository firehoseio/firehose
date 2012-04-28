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
        cors_headers  = {
          'Access-Control-Allow-Origin'     => env['HTTP_ORIGIN'],
          'Access-Control-Allow-Methods'    => 'GET',
          'Access-Control-Max-Age'          => '1728000'
        }

        case method
        # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
        # close down the requeust, and the client then reconnects.
        when 'GET'
          p [:subscribed, cid, path]

          EM.next_tick do
            # Setup a subscription with a client id. We haven't subscribed yet here.
            subscription = Firehose::Subscription.new(cid)

            # Setup a timeout timer to tell clients that time out that everything is OK
            # and they should come back for more
            timer = EM.add_timer(timeout) do
              # We send a 204 OK to tell the client to reconnect.
              env['async.callback'].call [204, cors_headers, []]
              p [:timeout]
            end

            # Ok, now subscribe to the subscription.
            subscription.subscribe path do |payload|
              subscription.unsubscribe
              subscription = nil # Set this to nil so that our heart beat timer doesn't try to double unsub.
              EM.cancel_timer timer # Turn off the heart beat so we don't execute any of that business.
              env['async.callback'].call [200, cors_headers, [payload]]
            end

            # Unsubscribe from the subscription if its still open and something bad happened
            # or the heart beat triggered before we could finish.
            env['async.close'].callback do
              if subscription
                subscription.unsubscribe
                p [:close_unsubscription]
              end
            end
          end

          # Tell the web server that this will be an async response.
          Firehose::Rack::AsyncResponse

        # PUT is how we throw messages on to the fan-out queue.
        when 'PUT'
          body = env['rack.input'].read
          p [:put, path, body]
          Firehose::Publisher.new.publish(path, body)

          [202, {}, []]
        else
          [501, {'Content-Type' => 'text/plain'}, ["#{method} not supported."]]
        end
      end
    end

    class WebSocket < ::Rack::WebSocket::Application
      # Subscribe to a path and make some magic happen, mmkmay?
      def on_open(env)
        req   = ::Rack::Request.new(env)
        cid   = req.params['cid']
        path  = req.path

        @subscription = Firehose::Subscription.new(cid)
        @subscription.subscribe path do |payload|
          send_data payload
        end
      end

      # Delete the subscription if the thing even happened.
      def on_close(env)
        @subscription.unsubscribe if @subscription
      end

      # Log websocket level errors
      def on_error(env, error)
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