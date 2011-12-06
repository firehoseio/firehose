require "push/version"

module Push
  autoload :Configuration,  'push/configuration'
  autoload :Logging,        'push/logging'
  autoload :Backend,        'push/backend'
  autoload :Producer,       'push/producer'
  autoload :Consumer,       'push/consumer'
  autoload :Transport,      'push/transport'

  def self.config(&block)
    @config ||= Configuration.new
    block.call @config if block
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