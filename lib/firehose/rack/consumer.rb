require 'json'

module Firehose
  module Rack
    # Handles a subscription request over HTTP or WebSockets depeding on its abilities and
    # binds that to the Firehose::Server::Subscription class, which is bound to a channel that
    # gets published to.
    class Consumer
      class BasicHandler
        def last_message_sequence(subscription)
          # this is for backwards compatibility
          # prefer consistent :last_message_sequence from now on
          lms = subscription[:last_message_sequence] || subscription[:message_sequence]

          if subscription[:message_sequence]
            Firehose.logger.warn "Client used deprecated :message_sequence subscription format: #{subscription.inspect}"
          end

          lms.to_i
        end
      end

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
            last_message_sequence: last_sequence
          }
        end
      end

      def self.post_subscriptions(request)
        body = request.body.read
        subs = JSON.parse(body).map do |chan, val|
          # Hash is the newer format subscription message that supports
          # params
          if val.is_a? Hash
            {
              channel: chan,
              last_message_sequence: val["last_message_sequence"],
              params: val["params"]
            }
          # Otherwise the value of the JSON hash is implicitly the message
          # sequence
          else
            {
              channel: chan,
              last_message_sequence: val
            }
          end
        end

        if subs.empty?
          Firehose.logger.warn "Consumer.post_subscriptions: Empty / Invalid subscriptions POST body: #{body.inspect}"
        end

        subs
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
