require 'thor'
require 'thin'

module Firehose
  class CLI < Thor
    desc "server", "starts the firehose server"
    method_option :port, :type => :numeric, :default => Firehose::Default::URI.port, :required => true, :aliases => '-p'
    method_option :host, :type => :string, :default => '0.0.0.0', :required => true, :aliases => '-h'
    def server
      server = Thin::Server.new(options[:host], options[:port]) do
        run Firehose::Rack::App.new
      end
      server.start!
    end
  end
end