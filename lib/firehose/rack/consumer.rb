require 'json'

module Firehose
  module Rack
    # Handles a subscription request over HTTP or WebSockets depeding on its abilities and
    # binds that to the Firehose::Server::Subscription class, which is bound to a channel that
    # gets published to.
    class Consumer
      # Rack consumer transports
      autoload :HttpLongPoll, 'firehose/rack/consumer/http_long_poll'
      autoload :WebSocket,    'firehose/rack/consumer/web_socket'

      def call(env)
        websocket_request?(env) ? websocket.call(env) : http_long_poll.call(env)
      end

      # Memoized instance of web socket that can be configured from the rack app.
      def websocket
        @web_socket ||= WebSocket.new
      end

      # Memoized instance of http long poll handler that can be configured from the rack app.
      def http_long_poll
        @http_long_poll ||= HttpLongPoll.new
      end

      private
      # Determine if the incoming request is a websocket request.
      def websocket_request?(env)
        Firehose::Rack::Consumer::WebSocket.request?(env)
      end
    end
  end
end
