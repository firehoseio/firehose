require 'faye/websocket'
require 'oj'
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

        class Handler
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
            Oj.load(event.data) rescue {}
          end

          # Send a JSON message to the client
          # Expects message to be a Hash
          def send_message(message)
            @ws.send Oj.dump(message)
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
            seq = msg["message_sequence"]
            if msg["ping"] == "PING"
              Firehose.logger.debug "WS ping received, sending pong"
              send_message "pong" => "PONG"
            elsif !@subscribed && seq.kind_of?(Integer)
              Firehose.logger.debug "Subscribing at message_sequence #{seq}"
              subscribe seq
            end
          end

          # Log a message that the client has connected.
          def open(event)
            Firehose.logger.debug "WebSocket subscribed to `#{@req.path}`. Waiting for message_sequence..."
          end

          # Log a message that hte client has disconnected and reset the state for the class. Clean
          # up the subscribers to the channels.
          def close(event)
            if @deferrable
              @deferrable.fail :disconnect
              @channel.unsubscribe(@deferrable) if @channel
            end
            Firehose.logger.debug "WS connection `#{@req.path}` closing. Code: #{event.code.inspect}; Reason #{event.reason.inspect}"
          end

          # Subscribe the client to the channel on the server. Asks for
          # the last sequence for clients that reconnect.
          def subscribe(last_sequence)
            @subscribed = true
            @channel    = Server::Channel.new @req.path
            @deferrable = @channel.next_message last_sequence
            @deferrable.callback do |message, sequence|
              Firehose.logger.debug "WS sent `#{message}` to `#{@req.path}` with sequence `#{sequence}`"
              send_message "message" => message, "last_sequence" => last_sequence
              subscribe sequence
            end
            @deferrable.errback do |e|
              unless e == :disconnect
                Firehose.logger.error "WS Error: #{e}"
                EM.next_tick { raise e.inspect }
              end
            end
          end
        end

        class MultiplexingHandler < Handler
          class Subscription < Struct.new(:channel, :deferrable)
            def close
              deferrable.fail :disconnect
              channel.unsubscribe(deferrable)
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
              return subscribe_multiplexed(subscriptions)
            end

            if channel_names = msg[:multiplex_unsubscribe]
              return unsubscribe(channel_names)
            end

            if msg[:ping] == 'PING'
              Firehose.logger.debug "WS ping received, sending pong"
              return send_message "pong" => "PONG"
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
            subscriptions.each do |sub|
              Firehose.logger.debug "Subscribing multiplexed to: #{sub}"

              channel, sequence = sub[:channel], sub[:message_sequence]
              next if channel.nil?

              subscribe(channel, sequence.to_i)
            end
          end

          # Subscribe the client to the channel on the server. Asks for
          # the last sequence for clients that reconnect.
          def subscribe(channel_name, last_sequence)
            channel      = Server::Channel.new channel_name
            deferrable   = channel.next_message last_sequence
            subscription = Subscription.new(channel, deferrable)

            @subscriptions[channel_name] = subscription

            deferrable.callback do |message, sequence|
              send_message(
                "channel" => channel_name,
                "message" => message,
                "last_sequence" => last_sequence
              )
              Firehose.logger.debug "WS sent `#{message}` to `#{channel_name}` with sequence `#{sequence}`"
              subscribe channel_name, sequence
            end

            deferrable.errback do |e|
              EM.next_tick { raise e.inspect } unless e == :disconnect
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
