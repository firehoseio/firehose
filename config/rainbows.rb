# TODO - Dunno what a lot of this stuff is... Tune with benchmarks
# http://rainbows.rubyforge.org/Rainbows/Configurator.html

Rainbows! do
  use                       :EventMachine   # concurrency model
  worker_connections        400
  keepalive_timeout         0               # disables keepalives
  keepalive_requests        666             # default:100
  client_max_body_size      5 * 1024 * 1024 # 5 megabytes
  client_header_buffer_size 2 * 1024        # 2 kilobytes
end

# the rest of the Unicorn configuration...
worker_processes [ENV['WORKER_PROCESSES'].to_i, 1].max # Default to 1
working_directory ENV['WORKING_DIRECTORY'] if ENV['WORKING_DIRECTORY']
logger Firehose.logger
