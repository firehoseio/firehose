require "set"

module Firehose
  module Server
    # Configuration object for Firehose server.
    class Configuration
      attr_accessor :message_filter, :redis
      attr_reader :deprecated_channels

      def initialize
        @redis = Redis.new
        @message_filter = MessageFilter
        @deprecated_channels = Set.new
        @deprecated_channel_check = -> (_channel) { false }
      end

      def deprecated_channels=(channels)
        @deprecated_channels = Set.new(channels)
      end

      def deprecated_channel(&block)
        @deprecated_channel_check = block
      end

      def channel_deprecated?(channel)
        @deprecated_channels.include?(channel) ||
          !!@deprecated_channel_check.call(channel)
      end
    end
  end
end
