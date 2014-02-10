require 'json'

# TODO - Spec this thing out. Unfortunately its not tested at all, mostly because the JSON client
# is more important (and tested). Still, this should be tested, at least used by the specs
# to test HTTP functionality of the server.
module Firehose
  module Client
    module Consumer
      # TODO - Test this libs. I had to throw these quickly into our app so that we could get 
      #        some stress testing out of the way.
      # TODO - Replace the integration test clients with these guys. You'll want to refactor each
      #        transport to use on(:message), on(:conncect), and on(:disconnect) callbacks.
      TransportNotSupportedError = Class.new(RuntimeError)

      # Build up a benchmark client based on a given URI. Accepts ws:// and http:// for now.
      def self.parse(uri)
        case transport = ::URI.parse(uri).scheme
        # TODO - Fix ws:// transport! See class WebSocket below to udnerstand
        # why this doesn't work and support is dropped from the CLI.
        # when 'ws'
        #   Consumer::WebSocket.new(uri)
        when 'http'
          Consumer::HttpLongPoll.new(uri)
        else
          raise TransportNotSupportedError.new("Transport #{transport.inspect} not supported.")
        end
      end

      # TODO - This won't even work. Dropping ws:// above until this is tested. This thing
      # should be sending message sequences to Firehose.
      # Connect to Firehose via WebSockets and consume messages.
      class WebSocket
        attr_reader :url, :logger

        def initialize(url, logger = Firehose.logger)
          @url, @logger = url, logger
        end

        def request
          ws = Faye::WebSocket::Client.new(url)
          ws.onmessage = lambda do |event|
            logger.info "WS | #{event.data[0...40].inspect}"
          end
          ws.onclose = lambda do |event|
            logger.info "WS | Closed"
          end
          ws.onerror do
            logger.error "WS | Failed"
          end
        end
      end

      # Connect to Firehose via HTTP Long Polling and consume messages.
      class HttpLongPoll
        JITTER = 0.003

        attr_reader :url, :logger

        def initialize(url, logger = Firehose.logger)
          @url, @logger = url, logger
        end

        def request(last_sequence=0)
          http = EM::HttpRequest.new(url, :inactivity_timeout => 0).get(:query => {'last_event_id' => last_sequence})
          http.callback do
            case status = http.response_header.status
            when 200
              json = JSON.parse(http.response)
              next_sequence = json['last_sequence'].to_i
              message = json['message']

              logger.info "HTTP 200 | Next Sequence: #{next_sequence} - #{message[0...40].inspect}"
              EM::add_timer(jitter) { request next_sequence }
            when 204
              logger.info "HTTP 204 | Last Sequence #{last_sequence}"
              EM::add_timer(jitter) { request last_sequence }
            else
              logger.error "HTTP #{status} | Failed"
            end
          end
          http.errback do
            logger.error "Connection Failed"
          end
        end

      private
        # Random jitter between long poll requests.
        def jitter
          rand*JITTER
        end
      end
    end
  end
end