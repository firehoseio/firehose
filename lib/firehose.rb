require 'firehose/version'

require 'amqp'
require 'logger'

module Firehose
  autoload :Subscription, 'firehose/subscription'
  autoload :Publisher,    'firehose/publisher'
  autoload :Rack,         'firehose/rack'
  autoload :CLI,          'firehose/cli'

  # TODO move this into a configuration or session class.
  # Hang on to AMQP configuration settings.
  def self.amqp
    @amqp ||= Struct.new(:connection).new(AMQP.connect)
  end

  # TODO figure out a better way to memoize AMQP connection for production runtimes, and 
  # make it resetable for testing environment. Some sort of Firehose::Session object is probably
  # in order
  def self.reset!
    @amqp = nil
  end

  # Logging
  def self.logger
    @logger ||= Logger.new($stdout)
  end

  def self.logger=(logger)
    @logger = logger
  end
end