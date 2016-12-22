require "set"

module Firehose
  module Server
    # Configuration object for Firehose server.
    class Configuration
      attr_accessor :message_filter, :redis, :deprecated_channels_sync_interval
      attr_reader :deprecated_channels

      def initialize
        @redis = Redis.new
        @message_filter = MessageFilter
        @deprecated_channels = Set.new
        @deprecated_callback = nil

        # by default update deprecated channels list from redis every minute
        @deprecated_channels_sync_interval = 60

        EM.next_tick do
          EM.add_periodic_timer(deprecated_channels_sync_interval) do
            redis.connection.smembers(deprecated_channels_key).callback do |chans|
              Firehose.logger.debug "Updating deprecated channels from redis: #{chans.inspect}"
              @deprecated_channels = Set.new(chans)
            end
          end
        end
      end

      def deprecate_channel(channel)
        unless channel_deprecated?(channel)
          Firehose.logger.info "Deprecated channel: #{channel}"
          @deprecated_channels << channel
          redis.connection.sadd(deprecated_channels_key, channel)
        end
      end

      def undeprecate_channel(channel)
        if channel_deprecated?(channel)
          Firehose.logger.info "Undeprecated channel: #{channel}"
          @deprecated_channels.delete channel
          redis.connection.srem(deprecated_channels_key, channel)
        end
      end

      def deprecated_channels=(channels)
        @deprecated_channels = Set.new(channels)
        channels.each do |chan|
          redis.connection.sadd(deprecated_channels_key, chan)
        end
      end

      def deprecated_channel(&block)
        @deprecated_callback = block
      end

      def channel_deprecated?(channel)
        cb = @deprecated_callback
        @deprecated_channels.include?(channel) || !!(cb && cb.call(channel))
      end

      private

      def redis_key(key)
        Firehose::Server::Redis.key(:configuration, key)
      end

      def deprecated_channels_key
        @deprecated_channels_key ||= redis_key(:deprecated_channels)
      end
    end
  end
end
