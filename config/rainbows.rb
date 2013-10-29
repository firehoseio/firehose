# Configuration from http://rainbows.rubyforge.org/Rainbows/Configurator.html. Don't juse
# blindly copy and paste this configuration! Be sure you have read and understand the Rainbows
# configuration documentation for your environment.

Rainbows! do
  use                       :EventMachine   # concurrency model
  worker_connections        50              # Any higher and we start breaking rlimit defaults
  keepalive_timeout         0               # disables keepalives
  keepalive_requests        666             # default:100
  client_max_body_size      5 * 1024 * 1024 # 5 megabytes
  client_header_buffer_size 2 * 1024        # 2 kilobytes
end

# the rest of the Unicorn configuration...
worker_processes [ENV['WORKER_PROCESSES'].to_i, 1].max # Default to 1
working_directory ENV['WORKING_DIRECTORY'] if ENV['WORKING_DIRECTORY']
logger Firehose.logger