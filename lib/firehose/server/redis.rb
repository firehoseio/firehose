require "uri"

module Firehose
  module Server
    # Manages redis configuration and connections.
    class Redis
      DEFAULT_URL = "redis://127.0.0.1:6379/0".freeze
      KEY_DELIMITER = ":".freeze
      ROOT_KEY = "firehose".freeze

      attr_reader :url

      def initialize(url = self.class.url)
        @url = URI(url)
      end

      def connection
        EM::Hiredis.connect(@url)
      end

      # Generates keys for all firehose interactions with Redis. Ensures a root
      # key of `firehose`
      def self.key(*segments)
        segments.flatten.unshift(ROOT_KEY).join(KEY_DELIMITER)
      end

      def self.url
        ENV.fetch("REDIS_URL", DEFAULT_URL)
      end
    end
  end
end
