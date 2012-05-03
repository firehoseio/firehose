require 'logger'
require 'em-http'
require 'em-websocket-client'

require 'firehose'
Firehose.logger = Logger.new('/dev/null')

# Lets skip the verbosity of the thin for the test output.
require 'thin'
Thin::Logging.silent = true

# We use both EM::Http and Net::Http in this test lib. When EM:Http is fired up
# we're usually hitting thins for integrations, and when Net::Http we want to mock that up.
require 'webmock/rspec'
WebMock.allow_net_connect!

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.before(:each) do
    # For now, this resets the AMQP configuration between runs.
    Firehose.reset!
  end
end