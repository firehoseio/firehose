require 'rubygems'
require 'bundler/setup'
require 'push'
require 'rspec'
require 'push/test'
require 'em-ventually'
require 'logger'
require 'thin'

# Make our EM specs timeout if an assertion isn't made after 5 seconds
EM::Ventually.total_default = 5

# Shhhh up the thin logging
Thin::Logging.silent = true

# Reset stuff between tests
RSpec.configure do |config|
  config.before(:each) do
    # Reset configurations between runs so that we don't have to deal with recollecting connections
    Push.config = nil
    # Default the back-end to test for this runner
    Push.config.backend = :test
    # Keep our rspec output clean from the push logger
    Push.config.logger = Logger.new('/dev/null')
  end
end