module Firehose::Server
  class MetricsCollector
    DEFAULT_INTERVAL = 10 # in seconds
    attr_reader :logger, :redis

    def initialize(logger = Firehose.logger, redis = Firehose::Server.redis)
      @logger = logger
      @redis = redis
    end

    def start
      EM.next_tick do
        EM.add_periodic_timer(metrics_interval) do
          save_metrics
        end
      end
    end

    def save_metrics
      unless Firehose::Server.metrics.empty?
        logger.info "Saving metrics to Redis to bucket #{metrics_bucket.inspect}"
        redis.connection.set(metrics_bucket, Firehose::Server.metrics.to_json)
        Firehose::Server.metrics.clear!
      end
    end

    def metrics_interval
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
