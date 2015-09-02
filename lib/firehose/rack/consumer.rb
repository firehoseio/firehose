require 'oj'

module Firehose
  module Rack
    # Handles a subscription request over HTTP or WebSockets depeding on its abilities and
    # binds that to the Firehose::Server::Subscription class, which is bound to a channel that
    # gets published to.
    class Consumer
      # Rack consumer transports
      autoload :HttpLongPoll, 'firehose/rack/consumer/http_long_poll'
      autoload :WebSocket,    'firehose/rack/consumer/web_socket'

      MULTIPLEX_CHANNEL = "channels@firehose"

      def self.multiplexing_request?(env)
        env["PATH_INFO"].include? MULTIPLEX_CHANNEL
      end

      def self.multiplex_subscriptions(request)
        if request.get?
          query_string_subscriptions(request.env)
        elsif request.post?
          post_subscriptions(request)
        end
      end

      def self.query_string_subscriptions(env)
        query_params = ::Rack::Utils.parse_query(env["QUERY_STRING"])

        query_params["subscribe"].to_s.split(",").map do |sub|
          chan, last_sequence = sub.split("!")
          last_sequence = last_sequence.to_i
          last_sequence = 0 if last_sequence < 0
          {
            channel: chan,
            message_sequence: last_sequence
          }
        end
      end

      def self.post_subscriptions(request)
        body = request.body.read
        subs = Oj.load(body).map do |chan, last_sequence|
          last_sequence = 0 if last_sequence < 0
          {
            channel: chan,
            message_sequence: last_sequence
          }
        end
      end

      # Let the client configure the consumer on initialization.
      def initialize
        yield self if block_given?
      end

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
