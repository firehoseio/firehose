require "faraday"
require "uri"

module Firehose
  # Publish messages to Firehose via an HTTP interface.
  class Producer
    attr_reader :uri

    def initialize(uri = Firehose::Default::URI)
      @uri = URI.parse(uri.to_s)
      @uri.scheme ||= 'http'
    end

    # Publish the message via HTTP.
    def publish(message, channel, &block)
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