module Firehose
  module Server
    # A no-op message filter. This class is meant to be
    # extended by users for implementing channel middleware.
    class MessageFilter
      attr_reader :channel, :params

      def initialize(channel)
        @channel = channel
        @params = {}
      end

      def process(message)
      end

      def on_subscribe(params)
        @params = params
      end

      def on_unsubscribe
        @params = {}
      end
    end
  end
end
