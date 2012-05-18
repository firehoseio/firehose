require 'logger'
require 'em-http'
require 'em-websocket-client'
require 'hiredis'

# Skip logging if VERBOSE isn't set to true.
require 'firehose'
Firehose.logger = Logger.new('/dev/null') unless ENV['VERBOSE']

# Lets skip the verbosity of the thin for the test output.
require 'thin'
Thin::Logging.silent = true unless ENV['VERBOSE']

# We use both EM::Http and Net::Http in this test lib. When EM:Http is fired up
# we're usually hitting thins for integrations, and when Net::Http we want to mock that up.
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
      conn = Hiredis::Connection.new
      conn.connect("127.0.0.1", 6379)
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