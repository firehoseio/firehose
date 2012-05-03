require "faraday"
require "uri"

module Firehose
  # Publish messages to Firehose via an HTTP interface.
  class Producer

    # Exception gets raised when a 202 is _not_ received from the server after a message is published.
    PublishError = Class.new(RuntimeError)
    TimeoutError = Class.new(Faraday::Error::TimeoutError)

    # A DSL for publishing requests. This doesn't so much, but lets us call
    # Firehose::Producer#publish('message').to('channel'). Slick eh? If you don't like it,
    # just all Firehose::Producer#put('message', 'channel')
    class Builder
      def initialize(producer, message)
        @producer, @message = producer, message
        self
      end

      def to(channel, &callback)
        @producer.put(@message, channel, &callback)
      end
    end

    # URI for the Firehose server. This URI does not include the path of the channel.
    attr_reader :uri

    def initialize(uri = Firehose::Default::URI)
      @uri = URI.parse(uri.to_s)
      @uri.scheme ||= 'http'
    end

    # A DSL for publishing messages.
    def publish(message)
      Builder.new(self, message)
    end

    # Publish the message via HTTP.
    def put(message, channel, &block)
      response = conn.put do |req|
        req.path = channel
        req.body = message
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

  private
    # Build out a Faraday connection 
    def conn
      @conn ||= Faraday.new(:url => uri.to_s) do |builder|
        builder.adapter self.class.adapter
      end
    end
  end
end