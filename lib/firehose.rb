require 'firehose/version'

require 'em-hiredis'
require 'logger'

require 'firehose/rails' if defined?(::Rails::Engine)

module Firehose
  autoload :Subscription, 'firehose/subscription'
  autoload :Publisher,    'firehose/publisher'
  autoload :Producer,     'firehose/producer'
  autoload :Default,      'firehose/default'
  autoload :Rack,         'firehose/rack'
  autoload :CLI,          'firehose/cli'
  
  # Logging
  def self.logger
    @logger ||= Logger.new($stdout)
  end

  def self.logger=(logger)
    @logger = logger
  end
end
