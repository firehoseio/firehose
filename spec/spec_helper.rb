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

module Push::Test::AMQP
  # Expose an amqp.whatever method to the test environment
  def amqp
    @dsl ||= DSL.new
  end

  class DSL
    # Run a counter that ticks up and gives us a new channel
    def next_channel
      "/channel/#{@run ||= rand(9999999)}/#{(@counter ||= 0) and @counter += 1}"
    end

    def queues
      command 'list_queues'
    end

    def exchanges
      command 'list_exchanges'
    end

    def channels
      command 'list_channels'
    end
    
    def command(command)
      %x[rabbitmqctl -q #{command}].split(/\n/).map do |line|
        line.split(/\t/)
      end
    end
  end
end

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