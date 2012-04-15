require 'rack/websocket'

module Push
  module Rack
    AsyncResponse = [-1, {}, []]

    class HttpLongPoll
      def call(env)
        req     = ::Rack::Request.new(env)
        cid     = req.params['cid']
        path    = req.path
        method  = req.request_method

        case method
        # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
        # close down the requeust, and the client then reconnects.
        when 'GET'
          EM.next_tick do
            subscription = Push::Subscription.new(cid)
            subscription.subscribe path do |payload|
              subscription.unsubscribe
              env['async.callback'].call([200, {}, [payload]])
            end
          end

          Push::Rack::AsyncResponse

        # PUT is how we throw messages on to the fan-out queue.
        when 'PUT'
          body = env['rack.input'].read
          p [:put, path, body]
          Push::Publisher.new.publish(path, body)

          [202, {}, []]
        else
          [501, {}, ["#{method} not supported."]]
        end
      end
    end

    class WebSocket < ::Rack::WebSocket::Application
      # Subscribe to a path and make some magic happen, mmkmay?
      def on_open(env)
        req   = ::Rack::Request.new(env)
        cid   = req.params['cid']
        path  = req.path

        @subscription = Push::Subscription.new(cid)
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
        websocket_request?(env) ? WebSocket.new.call(env) : HttpLongPoll.new.call(env)
      end

    private
      def websocket_request?(env)
        env['HTTP_UPGRADE'] =~ /websocket/i
      end
    end
  end
end