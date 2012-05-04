require 'thor'
require 'thin'

module Firehose
  class CLI < Thor
    desc "server", "starts the firehose server"
    method_option :port, :type => :numeric, :default => Firehose::Default::URI.port, :required => true, :aliases => '-p'
    method_option :host, :type => :string, :default => '0.0.0.0', :required => true, :aliases => '-h'
    method_option :daemonize, :type => :boolean, :default => false, :required => false, :aliases => '-d'
    method_option :log, :type => :string, :default => 'firehose.log', :required => false, :aliases => '-l'

    def server
      broker = Firehose::Broker.new

      server = Thin::Server.new(options[:host], options[:port]) do
        # TODO move this into a socket... this is really janky, but I need to to troubleshoot
        # connection reference issues. I'd like to have this ancillary stuff accessiable via
        # a different port or even a socket.
        map '/_firehose/stats' do
          run Proc.new {
            [200, {'Content-Type' => 'text/plain'}, [broker.stats.inspect]]
          }
        end

        map '/' do
          run Firehose::Rack::App.new(broker)
        end
      end

      begin
        if options[:daemonize]
          server.pid_file = 'firehose.pid'
          server.log_file = options[:log]
          server.daemonize
        end
        server.start!
      rescue AMQP::TCPConnectionFailed => e
        Firehose.logger.error "Unable to connect to AMQP, are you sure it's running?"
      end
    end
  end
end