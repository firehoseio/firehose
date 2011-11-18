require "push/version"

module Push
  autoload :Configuration,  'push/configuration'
  autoload :Logging,        'push/logging'
  autoload :Backend,        'push/backend'
  autoload :Producer,       'push/producer'
  autoload :Transport,      'push/transport'
  
  # Register some default backends
  Backend.register_adapter(:test, Backend::Test)
  Backend.register_adapter(:amqp, Backend::AMQP)
  
  def self.config(&blk)
    @config ||= Configuration.new
    yield @config if block_given?
    @config
  end
  
  def self.config=(config)
    @config = config
  end
  
  def self.logger
    config.logger
  end

  def self.exception_reporter(e)
    Push.config.exception_reporter.call(e)
  end
end