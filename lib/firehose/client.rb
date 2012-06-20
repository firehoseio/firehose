require 'em-http'
require 'faye/websocket'

module Firehose
  module Client
    # Ruby clients that connect to Firehose to either publish or consume messages.
    module Producer
      # TODO - Move the Firehose producer.rb file/class in here and rename to Firehose::Client::Producer::Http.new() ..
    end

    module Consumer
      TransportNotSupportedError = Class.new(RuntimeError)

      # Build up a benchmark client based on a given URI. Accepts ws:// and http:// for now.
      def self.parse(uri)
        case transport = URI.parse(uri).scheme
        when 'ws'
          Consumer::WebSocket.new(uri)
        when 'http'
          Consumer::LongPoll.new(uri)
        else
          raise TransportNotSupportedError.new("Transport #{transport.inspect} not supported.")
        end
      end

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
      class LongPoll
        JITTER = 0.003

        attr_reader :url, :logger

        def initialize(url, logger = Firehose.logger)
          @url, @logger = url, logger
        end

        def request(last_sequence=0)
          http = EM::HttpRequest.new(url, :inactivity_timeout => 0).get(:query => {'last_message_sequence' => last_sequence})
          http.callback do
            case status = http.response_header.status
            when 200
              next_sequence = http.response_header['Pragma'].to_i
              logger.info "HTTP 200 | Next Sequence: #{next_sequence} - #{http.response[0...40].inspect}"
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