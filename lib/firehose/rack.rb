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
        queue_name = "#{cid}@#{path}"

        # TODO seperate out CORS logic as an async middleware with a Goliath web server.
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
            if queue = queues[queue_name]
              queue.live
            else
              queue = queues[queue_name] = Firehose::Subscription::Queue.new(cid, path)
            end

            # Setup a timeout timer to tell clients that time out that everything is OK
            # and they should come back for more
            long_poll_timer = EM::Timer.new(timeout) do
              # We send a 204 OK to tell the client to reconnect.
              env['async.callback'].call [204, response_headers, []]
              Firehose.logger.debug "HTTP wait `#{cid}@#{path}` timed out"
            end

            # Ok, now subscribe to the subscription.
            queue.pop do |message, subscription|
              long_poll_timer.cancel # Turn off the heart beat so we don't execute any of that business.
              env['async.callback'].call [200, response_headers, [message]]
              Firehose.logger.debug "HTTP sent `#{message}` to `#{cid}@#{path}`"
            end
            Firehose.logger.debug "HTTP subscribed to `#{cid}@#{path}`"

            # Unsubscribe from the subscription if its still open and something bad happened
            # or the heart beat triggered before we could finish.
            env['async.close'].callback do
              # Kill queue if we don't hear back in 30s
              queue.kill timeout do
                Firehose.logger.debug "Deleting queue to `#{queue_name}`"
                queues.delete queue_name
              end
              Firehose.logger.debug "HTTP connection `#{cid}@#{path}` closing"
            end
          end

          # Tell the web server that this will be an async response.
          Firehose::Rack::AsyncResponse

        # PUT is how we throw messages on to the fan-out queue.
        when 'PUT'
          body = env['rack.input'].read
          Firehose.logger.debug "HTTP published `#{body}` to `#{path}`"
          publisher.publish(path, body)

          [202, {}, []]
        else
          Firehose.logger.debug "HTTP #{method} not supported"
          [501, {'Content-Type' => 'text/plain'}, ["#{method} not supported."]]
        end
      end

    private 
      def publisher
        @publisher ||= Firehose::Publisher.new
      end

      def queues
        @queues ||= {}
      end
    end

    class WebSocket < ::Rack::WebSocket::Application
      attr_reader :cid, :path, :subscription
      
      # Subscribe to a path and make some magic happen, mmkmay?
      def on_open(env)
        req   = ::Rack::Request.new(env)
        @cid   = req.params['cid']
        @path  = req.path
        @subscription = Firehose::Subscription.new(cid, path)

        subscription.subscribe do |message, subscription|
          Firehose.logger.debug "WS sent `#{message}` to `#{cid}@#{path}`"
          send_data message
        end
        Firehose.logger.debug "WS subscribed to `#{cid}@#{path}`"
      end

      # Delete the subscription if the thing even happened.
      def on_close(env)
        subscription.unsubscribe
        Firehose.logger.debug "WS connection `#{cid}@#{path}` closing"
      end

      # Log websocket level errors
      def on_error(env, error)
        Firehose.logger.error "WS connection `#{cid}@#{path}` error `#{error}`: #{error.backtrace}"
      end
    end

    class App
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
    end
  end
end