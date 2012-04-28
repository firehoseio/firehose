require 'thor'
require 'thin'

module Firehose
  class CLI < Thor
    desc "server", "starts the firehose server"
    method_option :port, :type => :numeric, :default => 7474, :required => true, :aliases => '-p'
    method_option :host, :type => :string, :default => '0.0.0.0', :required => true, :aliases => '-h'
    def server
      server = Thin::Server.new(options[:host], options[:port]) do
        run Firehose::Rack::App.new
      end

      begin
        server.start!
      rescue AMQP::TCPConnectionFailed => e
        Firehose.logger.error "Unable to connect to AMQP, are you sure it's running?"
      end
    end
  end
end