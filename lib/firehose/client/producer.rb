require "faraday"
require "uri"

module Firehose
  module Client
    module Producer
      # Publish messages to Firehose via an HTTP interface.
      class Http
        autoload :Async, 'firehose/client/producer/async'

        # A DSL for publishing requests. This doesn't so much, but lets us call
        # Firehose::Client::Producer::Http#publish('message').to('channel'). Slick eh? If you don't like it,
        # just all Firehose::Client::Producer::Http#put('message', 'channel')
        # For async sending use Firehose::Client::Producer::Http#publish('message').async.to('channel')
        # or Firehose::Client::Producer::Http#async_put('message', 'channel')
        class Builder
          def initialize(producer, message)
            @producer, @message = producer, message
            self
          end

          def to(channel, opts={}, &callback)
            @producer.send(@method || :put, @message, channel, opts, &callback)
          end

          def async
            @method = :async_put
            self
          end
        end

        # URI for the Firehose server. This URI does not include the path of the channel.
        attr_reader :uri

        def initialize(uri = Firehose::URI)
          @uri = ::URI.parse(uri.to_s)
          @uri.scheme ||= 'http'
          @async = Async.new self
        end

        # A DSL for publishing messages.
        def publish(message)
          Builder.new(self, message)
        end

        def batch_publish(data, opts={}, &block)
          PostRequest.new(self, data, opts={}, &block).process
        end

        # Publish the message via HTTP.
        def put(message, channel, opts, &block)
          PutRequest.new(self, message, channel, opts, &block).process
        end

        # Publish the message in batches via a background process.
        # Note that although the interface here looks identical to #put, the argument
        # passed to the callback block will be slightly different. Since the
        # messages are published in blocks, there is only a single response
        # object. That is what will be passed back.
        def async_put(message, channel, opts, &block)
          @async.enqueue(message, channel, opts, &block)
        end

        # Handle errors that could happen while publishing a message.
        def on_error(&block)
          @error_handler = block
        end

        # Raise an exception if an error occurs when connecting to the Firehose.
        def error_handler
          @error_handler || Proc.new{ |e| raise e }
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

        # Build out a Faraday connection
        def connection
          @connection ||= Faraday.new(:url => uri.to_s) do |builder|
            builder.adapter self.class.adapter
          end
        end


        # Exception gets raised when an unexpected status code is received
        # from the server after a message is published.
        PublishError = Class.new(RuntimeError)
        TimeoutError = Class.new(Faraday::Error::TimeoutError)

        class Request #:nodoc:
          DEFAULT_TIMEOUT = 1 # How many seconds should we wait for a publish to take?

          def initialize
            fail NotImplementedError
          end

          def process
            send_request
            handle_response

          # Hide Faraday with this Timeout exception, and through the error handler.
          rescue Faraday::Error::TimeoutError => e
            error_handler.call TimeoutError.new(e)
          end


          private

          def timeout
            @opts[:timeout] || DEFAULT_TIMEOUT
          end

          def conn
            @conn ||= @producer.connection
          end

          def error_handler
            @error_handler ||= @producer.error_handler
          end

          def handle_response
            @response.on_complete do
              case @response.status
              when success_status # Fire off the callback if everything worked out OK.
                @block.call(@response) if @block
              else
                error_handler.call PublishError.new("#{error_message}: #{@response.inspect}")
              end
            end
          end

          def ttl
          end

          def connection_settings
            Proc.new do |req|
              req.options[:timeout] = timeout
              req.path = path
              req.body = body
              req.headers['Cache-Control'] = "max-age=#{ttl.to_i}" if ttl
            end
          end
        end

        class PutRequest < Request #:nodoc:
          def initialize(producer, message, channel, opts, &block)
            @producer, @message, @channel, @opts, @block = producer, message, channel, opts, block
          end


          private

          def ttl
            ttl = @opts[:ttl]
          end

          def uri
            @producer.uri
          end


          def send_request
            @response = conn.put &connection_settings
          end

          def body
            @message
          end

          def path
            if conn.path_prefix.nil? || conn.path_prefix == '/'
              # This avoids a double / if the channel starts with a / too (which is expected).
              @channel
            else
              if conn.path_prefix =~ /\/\Z/ || @channel =~ /\A\//
                [conn.path_prefix, @channel].compact.join
              else
                # Add a / so the prefix and channel aren't just rammed together.
                [conn.path_prefix, @channel].compact.join('/')
              end
            end
          end

          def success_status
            202
          end

          def error_message
            "Could not publish #{@message.inspect} to '#{uri.to_s}/#{@channel}'"
          end
        end


        class PostRequest < Request #:nodoc:
          def initialize(producer, data, opts={}, &block)
            @producer, @data, @opts, @block = producer, data, opts, block
          end

          private

          def send_request
            @response = conn.post &connection_settings
          end

          def body
            @data.to_json
          end

          def path
            "/" # all batch publishing goes to root
          end

          def success_status
            200
          end

          def error_message
            "Could not batch publish #{@data.inspect}:"
          end
        end
      end
    end
  end
end
