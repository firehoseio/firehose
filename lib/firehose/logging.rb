# Sets up logging

require 'logger'

module Firehose
  def self.logger
    @logger ||= Logger.new($stdout)
  end

  def self.logger=(logger)
    @logger = logger
  end

  self.logger.level = if ENV['LOG_LEVEL']
    Logger.const_get(ENV['LOG_LEVEL'].upcase)
  else
    case ENV['RACK_ENV']
      when 'test'         then Logger::ERROR
      when 'development'  then Logger::DEBUG
      else Logger::INFO
    end
  end

  # TODO: Provide some way to allow this to be configured via an ENV variable.
  self.logger.formatter = lambda do |severity, time, name, msg|
    out_time = time.utc.strftime "%Y-%m-%d %H:%M:%S.%L"
    "[#{out_time} ##$$] #{severity} : #{msg}\n"
  end
end

EM::Hiredis.logger = Firehose.logger

# stdout gets "lost" in Foreman if this isn't here
# https://github.com/ddollar/foreman/wiki/Missing-Output
$stdout.sync = true if ENV['RACK_ENV'] == 'development' || ENV['SYNC_LOGGING']


Firehose.logger.info "Starting #{Firehose::VERSION} '#{Firehose::CODENAME}', in #{ENV['RACK_ENV']}"
