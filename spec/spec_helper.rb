ENV['RACK_ENV'] ||= 'test'

require 'logger'
require 'eventmachine'
require 'em-http'
require 'faye/websocket'
require 'hiredis'
require 'firehose'

# Test coverage reports on CodeClimate.
begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
end

# We use both EM::Http and Net::Http in this test lib. When EM:Http is fired up
# we're usually hitting Rainbows! for integrations, and when Net::Http we want
# to mock that up.
require 'webmock/rspec'
WebMock.allow_net_connect!

module EM::TestHelper
  # Run test inside of reactor.
  def em(ttl=30, &block)
    if block
      # Run the block inside of a reactor
      EM.run do
        EM.add_timer(ttl) do
          EM.stop
          raise "Test timed-out"
        end
        block.call(EM)
      end
    else # or just grab em and go nuts.
      EM
    end
  end
end

module Hiredis::TestHelper
  def redis
    @conn ||= begin
      redis = Firehose::Server.configuration.redis
      conn = Hiredis::Connection.new
      conn.connect(redis.url.host, redis.url.port)
      conn
    end
  end

  def reset_redis
    redis_exec 'flushdb'
  end

  def redis_exec(*tokens)
    redis.write tokens
    redis.read
  end
end

# Configure RSpec runner. See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.include Hiredis::TestHelper
  config.before(:each) do
    reset_redis
  end
end

# Allow async responses to get through rack/lint
require 'rack/lint'
class Rack::Lint
  def check_status_with_async(status)
    check_status_without_async(status) unless status == -1
  end
  alias_method :check_status_without_async, :check_status
  alias_method :check_status, :check_status_with_async

  def check_content_type_with_async(status, headers)
    check_content_type_without_async(status, headers) unless status == -1
  end
  alias_method :check_content_type_without_async, :check_content_type
  alias_method :check_content_type, :check_content_type_with_async
end
