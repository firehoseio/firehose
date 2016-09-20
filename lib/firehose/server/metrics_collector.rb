module Firehose::Server
  class MetricsCollector
    DEFAULT_INTERVAL = 10 # in seconds
    attr_reader :logger, :redis

    def initialize(logger = Firehose.logger, redis = Firehose::Server.redis)
      @logger = logger
      @redis = redis
    end

    def start
      logger.info "Starting MetricsCollector with an interval of #{metrics_interval}s"
      EM.next_tick do
        # Disable for now and just keep metrics in memory
        # EM.add_periodic_timer(metrics_interval) do
        #   save_metrics
        # end
        EM.add_periodic_timer(metrics_interval * 1.3) do
          clear_old_metrics
        end
      end
    end

    def clear_old_metrics
      logger.debug "Clearing old metrics"
      Firehose::Server.metrics.clear_old!
    end

    def save_metrics
      unless Firehose::Server.metrics.empty?
        bucket = metrics_bucket
        logger.info "Saving metrics to Redis to bucket #{bucket.inspect}"
        redis.connection.set(bucket, metrics_data)
      end
    end

    def metrics_data
      Firehose::Server.metrics.to_json
    end

    def metrics_interval
      self.class.metrics_interval
    end

    def self.metrics_interval
      @interval ||= begin
        if (i = ENV["METRICS_INTERVAL"].to_i) > 0
          i
        else
          DEFAULT_INTERVAL
        end
      end
    end

    def metrics_bucket
      now = Time.now.to_i
      bucket_id = now - (now % metrics_interval)
      Firehose::Server::Redis.key :metrics, bucket_id
    end
  end
end
