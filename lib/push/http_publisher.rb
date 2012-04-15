require "net/http"
require "uri"

module Push
  class HttpPublisher
    attr_reader :uri

    class RequestBuilder
      attr_reader :uri, :message, :channel

      def initialize(uri, message)
        @uri, @message = uri, message
      end

      def to(channel)
        req = Net::HTTP::Put.new(channel)
        req.body = message
        res = Net::HTTP.start(uri.host, uri.port) do |http|
          response = http.request(req)
        end
      end
    end

    def initialize(uri)
      @uri = URI.parse(uri)
    end

    def publish(message)
      RequestBuilder.new(uri, message)
    end
  end
end