require 'faye/websocket'
require 'em-hiredis'

# Set the EM::Hiredis logger to be the same as the Firehose logger.
EM::Hiredis.logger = Firehose.logger

module Firehose
  # Firehose components that sit between the Rack HTTP software and the Redis server.
  # This mostly handles message sequencing and different HTTP channel names.
  module Server
    autoload :Configuration,       'firehose/server/configuration'
    autoload :Message,             'firehose/server/message'
    autoload :MessageFilter,       'firehose/server/message_filter'
    autoload :MessageBuffer,       'firehose/server/message_buffer'
    autoload :Subscriber,          'firehose/server/subscriber'
    autoload :Publisher,           'firehose/server/publisher'
    autoload :ChannelSubscription, 'firehose/server/channel_subscription'
    autoload :App,                 'firehose/server/app'
    autoload :Redis,               'firehose/server/redis'
    autoload :Metrics,             'firehose/server/metrics'
    autoload :MetricsCollector,    'firehose/server/metrics_collector'

    def self.configuration
      @configuration ||= Configuration.new
      yield(@configuration) if block_given?
      @configuration
    end

    def self.redis
      configuration.redis
    end

    def self.metrics
      interval = ENV["METRICS_INTERVAL"].to_i
      interval = MetricsCollector.metrics_interval
      @metrics ||= Firehose::Server::Metrics::TimeSeries.new(seconds: interval)
    end
  end
end
