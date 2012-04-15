require 'push/version'

require 'amqp'

module Push
  autoload :Subscription, 'push/subscription'
  autoload :Publisher,    'push/publisher'
  autoload :Goliath,      'push/goliath'
  autoload :Rack,         'push/rack'

  # TODO move this into a configuration or session class.
  # Hang on to AMQP configuration settings.
  def self.amqp
    @amqp ||= Struct.new(:connection).new(AMQP.connect)
  end

  # TODO figure out a better way to memoize AMQP connection for production runtimes, and 
  # make it resetable for testing environment. Some sort of Push::Session object is probably
  # in order
  def self.reset!
    @amqp = nil
  end
end