module Firehose::Server
  class MetricsCollector
    DEFAULT_INTERVAL = 10 # in seconds
    attr_reader :logger

    def initialize(logger = Firehose.logger)
      @logger = logger
    end

    def start
      EM.next_tick do
        EM.add_periodic_timer(metrics_interval) do
          save_metrics
        end
      end
    end

    def save_metrics
      logger.info "Saving metrics to Redis to bucket #{metrics_bucket.inspect}"
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
      Time.now.to_i % metrics_interval
    end
  end
end
