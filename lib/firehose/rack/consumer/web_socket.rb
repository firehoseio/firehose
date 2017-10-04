require 'faye/websocket'
require 'json'
require "rack/utils"

module Firehose
  module Rack
    class Consumer
      class WebSocket
        # Setup a handler for the websocket connection.
        def call(env)
          ws = Faye::WebSocket.new(env)
          if Consumer.multiplexing_request?(env)
            MultiplexingHandler.new(ws)
          else
            DefaultHandler.new(ws)
          end
          ws.rack_response
        end

        # Determine if the rack request is a WebSocket request.
        def self.request?(env)
          Faye::WebSocket.websocket?(env)
        end

        class Handler < Firehose::Rack::Consumer::BasicHandler
          def initialize(ws)
            @ws = ws
            @req = ::Rack::Request.new ws.env
            # Setup the event handlers from this class.
            @ws.onopen    = method :open
            @ws.onclose   = method :close
            @ws.onerror   = method :error
            @ws.onmessage = method :message
          end

          def parse_message(event)
            JSON.parse(event.data, :symbolize_names => true) rescue {}
          end

          # Send a JSON message to the client
          # Expects message to be a Hash
          def send_message(message)
            @ws.send JSON.generate(message)
          end

          # Log errors if a socket fails. `close` will fire after this to clean up any
          # remaining connectons.
          def error(event)
            Firehose.logger.error "WS connection `#{@req.path}` error. Message: `#{event.message.inspect}`"
          end
        end

        # Manages connection state for the web socket that's connected
        # by the Consumer::WebSocket class. Deals with message sequence,
        # connection, failures, and subscription state.
        class DefaultHandler < Handler
          # Manages messages sent from the connect client to the server. This is mostly
          # used to handle heart-beats that are designed to prevent the WebSocket connection
          # from timing out from inactivity.
          def message(event)
            msg = parse_message(event)
            seq = last_message_sequence(msg)
            if msg[:ping] == 'PING'
              Firehose.logger.debug "WS ping received, sending pong"
              send_message pong: "PONG"
            elsif !@subscribed && seq.kind_of?(Integer)
              Firehose.logger.debug "Subscribing at message_sequence #{seq}"
              subscribe seq, @req.params
            end
          end

          # Log a message that the client has connected.
          def open(event)
            Firehose.logger.debug "WebSocket subscribed to `#{@req.path}`. Waiting for last_message_sequence..."
            Firehose::Server.metrics.new_connection!
          end

          # Log a message that the client has disconnected and reset the state for the class. Clean
          # up the subscribers to the channels.
          def close(event)
            disconnect
            Firehose.logger.debug "WS connection `#{@req.path}` closing. Code: #{event.code.inspect}; Reason #{event.reason.inspect}"
            Firehose::Server.metrics.connection_closed!
          end

          def disconnect
            if @deferrable
              @deferrable.fail :disconnect
              @chan_sub.unsubscribe if @chan_sub
            end
          end

          # Subscribe the client to the channel on the server. Asks for
          # the last sequence for clients that reconnect.
          def subscribe(last_sequence, params)
            begin
              @subscribed = true
              @chan_sub   = Server::ChannelSubscription.new @req.path,
                                                            params: params,
                                                            sequence: last_sequence
              @deferrable = @chan_sub.next_messages
              @deferrable.callback do |messages|
                messages.each do |message|
                  Firehose.logger.debug "WS sent `#{message.payload}` to `#{@req.path}` with sequence `#{message.sequence}`"
                  send_message message: message.payload, last_sequence: message.sequence
                end
                subscribe messages.last.sequence, params
              end
              @deferrable.errback do |e|
                unless e == :disconnect
                  Firehose.logger.error "WS Error: #{e}"
                  EM.next_tick { raise e.inspect }
                end
              end
            rescue Server::ChannelSubscription::Failed => e
              Firehose.logger.info "Subscription failed: #{e.message}"
              send_message error: "Subscription failed", reason: e.message
              disconnect
            end
          end
        end

        class MultiplexingHandler < Handler
          class Subscription < Struct.new(:channel, :deferrable)
            def close
              deferrable.fail :disconnect
              channel.unsubscribe
            end
          end

          def initialize(ws)
            super(ws)
            @subscriptions = {}
            subscribe_multiplexed Consumer.multiplex_subscriptions(@req)
          end

          def message(event)
            msg = parse_message(event)

            if subscriptions = msg[:multiplex_subscribe]
              subscriptions = [subscriptions] unless subscriptions.is_a?(Array)
              Firehose::Server.metrics.channels_subscribed_multiplexed_ws_dynamic!(subscriptions)
              return subscribe_multiplexed(subscriptions)
            end

            if channel_names = msg[:multiplex_unsubscribe]
              return unsubscribe(channel_names)
            end

            if msg[:ping] == 'PING'
              Firehose.logger.debug "WS ping received, sending pong"
              return send_message pong: "PONG"
            end
          end

          def open(event)
            Firehose.logger.debug "Multiplexing Websocket connected: #{@req.path}"
          end

          def close(event)
            @subscriptions.each_value(&:close)
            @subscriptions.clear
          end

          def subscribe_multiplexed(subscriptions)
            channels = subscriptions.map{|s| s[:channel]}
            Firehose::Server.metrics.channels_subscribed_multiplexed_ws!(channels)

            subscriptions.each do |sub|
              Firehose.logger.debug "Subscribing multiplexed to: #{sub}"

              channel, sequence = sub[:channel]

              next if channel.nil?

              if @subscriptions.include?(channel)
                Firehose.logger.warn "Duplicate (aborted) multiplexing WS channel subscription: #{channel}"
                Firehose::Server.metrics.duplicate_multiplex_ws_subscription!
                # skip duplicate channel subscriptions
                next
              end

              subscribe(channel, last_message_sequence(sub), sub[:params])
            end
          end

          # Subscribe the client to the channel on the server. Asks for
          # the last sequence for clients that reconnect.
          def subscribe(channel_name, last_sequence, params)
            chan_sub = Server::ChannelSubscription.new(
              channel_name,
              params: params,
              sequence: last_sequence
            )

            deferrable   = chan_sub.next_messages
            subscription = Subscription.new(chan_sub, deferrable)

            @subscriptions[channel_name] = subscription

            deferrable.callback do |messages|
              messages.each do |message|
                send_message(
                  channel: channel_name,
                  message: message.payload,
                  last_sequence: message.sequence
                )
                Firehose.logger.debug "WS sent `#{message.payload}` to `#{channel_name}` with sequence `#{message.sequence}`"
              end
              subscribe channel_name, messages.last.sequence, params
            end

            deferrable.errback do |e|
              unless e == :disconnect
                Firehose::Server.metrics.error!(:ws_subscribe_multiplexed, channel_name)
                EM.next_tick { raise e.inspect }
              end
            end
          end

          def unsubscribe(channel_names)
            Firehose.logger.debug "Unsubscribing from channels: #{channel_names}"
            Array(channel_names).each do |chan|
              if sub = @subscriptions[chan]
                sub.close
                @subscriptions.delete(chan)
              end
            end
          end
        end
      end
    end
  end
end
