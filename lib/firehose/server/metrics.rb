require "set"

module Firehose::Server
  module Metrics
    class TimeSeries
      attr_reader :series

      def initialize(seconds: 5, keep_buckets: 2)
        @seconds = seconds.to_i
        if @seconds < 1
          raise ArgumentError, "TimeSeries interval must be >= 1"
        end
        @keep_buckets = keep_buckets
        clear!
      end

      def method_missing(method, *args)
        current.send(method, *args)
      end

      def clear!
        @series = Hash.new do |h, k|
          bucket = bucket(k)
          h[bucket] = Firehose::Server::Metrics::Buffer.new(bucket)
        end
      end

      def clear_old!
        # keep latest @keep_buckets buckets
        buckets = []
        @keep_buckets.times do |i|
          bucket = bucket(Time.now) - (i * @seconds)
          buckets << [bucket, @series[bucket]]
        end
        clear!
        # use reverse_each to keep insertion order correct
        # (Hash keys are insertion ordered)
        buckets.reverse_each do |(bucket, buffer)|
          @series[bucket] = buffer
        end
        @series
      end

      def to_json
        JSON.generate @series.values.map(&:to_hash)
      end

      def empty?
        @series.empty?
      end

      # private

      def current
        @series[bucket(Time.now)]
      end

      def bucket(time)
        secs = time.to_i
        secs - (secs % @seconds)
      end
    end

    class Buffer
      def initialize(time_bucket)
        @time_bucket = time_bucket
        @active_channels = Set.new
        @global = Hash.new { 0 }
        @channel_metrics = Hash.new
      end

      # metric handlers

      def message_published!(channel, message = nil)
        @active_channels << channel
        incr_global! :published
        incr_channel! channel, :published

        cm = channel_metrics(channel)
        if message
          incr_channel! channel, :total_size, message.size
        end
      end

      def channel_subscribed!(channel)
        @active_channels << channel
        incr_global! :subscribed
        incr_channel! channel, :subscribed
      end

      def channels_subscribed_multiplexed_ws!(channels)
        channels.each do |channel|
          @active_channels << channel
          incr_global! :subscribed_multiplexed_ws
          incr_channel! channel, :subscribed_multiplexed_ws
        end
      end

      def channels_subscribed_multiplexed_long_polling!(channels)
        channels.each do |channel|
          @active_channels << channel
          incr_global! :subscribed_multiplexed_long_polling
          incr_channel! channel, :subscribed_multiplexed_long_polling
        end
      end

      def channels_subscribed_multiplexed_ws_dynamic!(subscriptions)
        incr_global! :subscribed_multiplexed_ws_dynamic, subscriptions.size
      end

      def duplicate_multiplex_ws_subscription!
        incr_global! :duplicate_multiplex_subscription
      end

      def new_connection!
        incr_global! :connections
        incr_global! :connections_opened
      end

      def connection_closed!
        incr_global! :connections_closed
        decr_global! :connections
      end

      # serialization helpers (used to store metrics to redis)

      def to_hash
        {
          time: @time_bucket,
          global: @global.merge(active_channels: @active_channels.size),
          channels: @channel_metrics
        }
      end

      def to_json
        JSON.generate self.to_hash
      end

      def == other
        self.to_hash == other.to_hash
      end

      private

      def incr_global!(name, increment = 1)
        @global[name] += increment
      end

      def decr_global!(name, decrement = 1)
        @global[name] -= decrement
      end

      def incr_channel!(channel, counter, increment = 1)
        channel_metrics(channel)[counter] += increment
      end

      def decr_channel!(channel, counter, decrement = 1)
        channel_metrics(channel)[counter] -= decrement
      end

      def channel_metrics(channel)
        @channel_metrics[channel] ||= Hash.new { 0 }
      end
    end
  end
end
