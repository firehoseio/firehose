require "faraday"
require "uri"

module Firehose
  # Publish messages to Firehose via an HTTP interface.
  class Producer

    # A DSL for publishing requests.
    class Builder
      def initialize(producer, message)
        @producer, @message = producer, message
        self
      end

      def to(channel, &callback)
        @producer.put(@message, channel, &callback)
      end
    end

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
      conn.put do |req|
        req.path = channel
        req.body = message
      end.on_complete(&block)
    end

    # What adapter should Firehose use to PUT the message? List of adapters is
    # available at 
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
        builder.adapter   self.class.adapter
        builder.response  :logger
      end
    end
  end
end