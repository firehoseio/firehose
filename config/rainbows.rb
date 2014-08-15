# Configuration from http://rainbows.rubyforge.org/Rainbows/Configurator.html. Don't juse
# blindly copy and paste this configuration! Be sure you have read and understand the Rainbows
# configuration documentation for your environment.

Rainbows! do
  use                       :EventMachine   # concurrency model
  worker_connections        400
  
  # keepalives are useful to make frequent and rapid publishing more
  # efficient by reducing TCP/IP connection overhead.
  keepalive_timeout         Firehose::Server::HTTP_KEEPALIVE

  # This should match or exceed the number of publishers running
  # on the remote servers. In a produciton environment you will
  # want to run publishers seperate from subsribers to make sure
  # subscribers don't use all of the keepalive connections.
  keepalive_requests        100             # default:100

  # Maximum Firehose message payload size.
  client_max_body_size      5 * 1024 * 1024 # 5 megabytes

  # Maximum size of header data in a Firehose publish or subscirbe.
  client_header_buffer_size 2 * 1024        # 2 kilobytes
end

# the rest of the Unicorn configuration...
worker_processes [ENV['WORKER_PROCESSES'].to_i, 1].max # Default to 1
working_directory ENV['WORKING_DIRECTORY'] if ENV['WORKING_DIRECTORY']
logger Firehose.logger