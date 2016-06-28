module Firehose
  module Server
    # Configuration object for Firehose server.
    class Configuration
      attr_accessor :message_filter, :redis

      def initialize
        @redis = Redis.new
        @message_filter = MessageFilter
      end
    end
  end
end
