require "json"

module Firehose
  module Rack
    class MetricsAPI
      include Firehose::Rack::Helpers

      def initialize
      end

      def call(env)
        Firehose.logger.info "MetricsAPI GET request"
        response(200, Firehose::Server.metrics.to_json)
      end
    end
  end
end
