module Firehose
  module Server
    # A no-op message filter. This class is meant to be
    # extended by users for implementing channel middleware.
    class MessageFilter
      def initialize(channel)
        @channel = channel
      end

      def process(message)
      end

      def on_subscribe(params)
      end

      def on_unsubscribe
      end
    end
  end
end
