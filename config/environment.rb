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

# Use exceptional to handle anything missed by Rack::Exceptional
if exceptional_key = ENV['EXCEPTIONAL_KEY']
  require 'exceptional'
  EM.error_handler do |e|
    Firehose.logger.error "Unhandled exception: #{e.class} #{e.message}\n#{e.backtrace.join "\n"}"
    ::Exceptional.handle(e)
  end
end
