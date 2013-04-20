module Firehose
  module Rack
    class Ping
      attr_reader :redis

      def initialize(redis=nil)
        @redis = redis
      end

      def call(env)
        PingCheck.new(env, redis).call
        ASYNC_RESPONSE
      end


      # Encapsulate this in a class so we aren't passing a bunch of variables around
      class PingCheck
        include Firehose::Rack::Helpers

        attr_reader :req, :env, :key, :redis

        TEST_VALUE = 'Firehose Healthcheck Test Value'
        SECONDS_TO_EXPIRE = 60

        def self.redis
          @redis ||= EM::Hiredis.connect
        end

        def initialize(env, redis=nil)
          @redis = redis || self.class.redis
          @env   = env
          @req   = env['parsed_request'] ||= ::Rack::Request.new(env)
          @key   = "/firehose/ping/#{Time.now.to_i}/#{rand}"
        end

        def call
          log req, 'started'
          test_redis
        end


        private

        def log(req, msg)
          Firehose.logger.debug "HTTP PING request for path '#{req.path}': #{msg}"
        end

        def test_redis
          redis.set(key, TEST_VALUE).
            callback { expire_key }.
            callback { read_and_respond }.
            errback do |e|
              log req, "failed with write value to redis: #{e.inspect}"
              env['async.callback'].call response(500)
            end
        end

        def expire_key
          redis.expire(key, SECONDS_TO_EXPIRE).
            errback do
              log req, "failed to expire key #{key.inspect}. If this key is not manually deleted, it may cause a memory leak."
            end
        end

        def read_and_respond
          redis.get(key).
            callback do |val|
              if val == TEST_VALUE
                log req, 'succeeded'
                env['async.callback'].call response(200)
              else
                log req, "failed with unexpected value retrieved from redis: #{val.inspect}"
                env['async.callback'].call response(500)
              end
            end.
            errback do |e|
              log req, "failed with read value from redis: #{e.inspect}"
              env['async.callback'].call response(500)
            end
        end
      end
    end
  end
end
