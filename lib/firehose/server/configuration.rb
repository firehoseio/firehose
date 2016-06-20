module Firehose
  module Server
    # Configuration object for Firehose server.
    class Configuration
      def initialize
        @redis = Redis.new
        @message_handler = MessageHandler.new
      end

      attr_reader :message_handler
      attr_reader :redis
    end
  end
end
