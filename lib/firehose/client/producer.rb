require "faraday"
require "uri"

module Firehose
  module Client
    module Producer
      # Publish messages to Firehose via an HTTP interface.
      class Http
        # Exception gets raised when a 202 is _not_ received from the server after a message is published.
        PublishError = Class.new(RuntimeError)
        TimeoutError = Class.new(Faraday::Error::TimeoutError)
        DEFAULT_TIMEOUT = 1 # How many seconds should we wait for a publish to take?
        DEFAULT_ERROR_HANDLER = ->(e) { raise e }

        # A DSL for publishing requests. This doesn't so much, but lets us call
        # Firehose::Client::Producer::Http#publish('message').to('channel'). Slick eh? If you don't like it,
        # just all Firehose::Client::Producer::Http#put('message', 'channel')
        class Builder
          def initialize(producer, message)
            @producer, @message = producer, message
            self
          end

          def to(channel, opts={}, &callback)
            @producer.put(@message, channel, opts, &callback)
          end
        end

        # URI for the Firehose server. This URI does not include the path of the channel.
        attr_reader :uri, :timeout
        attr_accessor :publish_secret

        def initialize(uri = Firehose::URI, timeout=DEFAULT_TIMEOUT)
          @uri = ::URI.parse(uri.to_s)
          @uri.scheme ||= 'http'
          @timeout = timeout
        end

        # A DSL for publishing messages.
        def publish(message)
          Builder.new(self, message)
        end

        # Publish the message via HTTP.
        def put(message, channel, opts, &block)
          ttl         = opts[:ttl]
          timeout     = opts[:timeout] || @timeout || DEFAULT_TIMEOUT
          buffer_size = opts[:buffer_size]

          response = conn.put do |req|
            req.options[:timeout] = timeout
            if conn.path_prefix.nil? || conn.path_prefix == '/'
              # This avoids a double / if the channel starts with a / too (which is expected).
              req.path = channel
            else
              if conn.path_prefix =~ /\/\Z/ || channel =~ /\A\//
                req.path = [conn.path_prefix, channel].compact.join
              else
                # Add a / so the prefix and channel aren't just rammed together.
                req.path = [conn.path_prefix, channel].compact.join('/')
              end
            end
            req.body = message
            req.headers['Cache-Control'] = "max-age=#{ttl.to_i}" if ttl
            req.headers["X-Firehose-Buffer-Size"] = buffer_size.to_s if buffer_size
          end
          response.on_complete do
            case response.status
            when 202 # Fire off the callback if everything worked out OK.
              block.call(response) if block
            else
              error_handler.call PublishError.new("Could not publish #{message.inspect} to '#{uri.to_s}/#{channel}': #{response.inspect}")
            end
          end

          # Hide Faraday with this Timeout exception, and through the error handler.
          rescue Faraday::Error::TimeoutError => e
            error_handler.call TimeoutError.new(e)
        end

        # Handle errors that could happen while publishing a message.
        def on_error(&block)
          @error_handler = block
        end

        # Raise an exception if an error occurs when connecting to the Firehose.
        def error_handler
          @error_handler || DEFAULT_ERROR_HANDLER
        end

        # What adapter should Firehose use to PUT the message? List of adapters is
        # available at https://github.com/technoweenie/faraday.
        def self.adapter=(adapter)
          @adapter = adapter
        end

        # Use :net_http for the default Faraday adapter.
        def self.adapter
          @adapter ||= Faraday.default_adapter
        end

        private
        # Build out a Faraday connection
        def conn
          @conn ||= Faraday.new(:url => uri.to_s) do |builder|
            builder.adapter self.class.adapter
            if @publish_secret
              builder.basic_auth("firehose", @publish_secret)
            end
          end
        end
      end
    end
  end
end
