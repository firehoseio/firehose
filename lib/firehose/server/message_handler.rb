module Firehose
  module Server
    # A no-op message handler. This class is meant to be
    # extended by users for implementing channel middleware.
    class MessageHandler
      def process(message: , channel: )
      end
    end
  end
end
