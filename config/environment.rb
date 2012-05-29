ENV['RACK_ENV'] ||= 'development'

Firehose.logger.level = if ENV['LOG_LEVEL']
  Logger.const_get(ENV['LOG_LEVEL'].upcase)
else
  case ENV['RACK_ENV']
    when 'test'         then Logger::ERROR
    when 'development'  then Logger::DEBUG
    else Logger::INFO
  end
end

Firehose.logger.formatter = lambda do |severity, time, name, msg|
  out_time = time.utc.strftime "%Y-%m-%d %H:%M:%S.%L"
  "[#{out_time} ##$$] #{severity} : #{msg}\n"
end

# stdout gets "lost" in Foreman if this isn't here
# https://github.com/ddollar/foreman/wiki/Missing-Output
$stdout.sync = ENV['RACK_ENV'] == 'development'

Firehose.logger.info "Starting #{Firehose::VERSION} '#{Firehose::CODENAME}', in #{ENV['RACK_ENV']}"
