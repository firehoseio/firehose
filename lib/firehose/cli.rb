require 'thor'
require 'eventmachine'
require 'uri'

module Firehose
  class CLI < Thor
    def initialize(*args)
      super
      # Disable buffering to $stdio for Firehose.logger
      $stdout.sync = true
    end

    desc "version", "display the current version"
    def version
      puts %[Firehose #{Firehose::VERSION} "#{Firehose::CODENAME}"]
    end

    desc "server", "starts the firehose server"
    method_option :port,   :type => :numeric, :default => ENV['PORT'] || Firehose::Default::URI.port, :required => false, :aliases => '-p'
    method_option :host,   :type => :string,  :default => ENV['HOST'] || Firehose::Default::URI.host, :required => false, :aliases => '-h'
    method_option :server, :type => :string,  :default => ENV['SERVER'] ||'rainbows', :required => false, :aliases => '-s'
    def server
      begin
        Firehose::Server.new(options).start
      rescue => e
        Firehose.logger.error "#{e.message}: #{e.backtrace}"
        raise e
      end
    end

    desc "consume URI", "Benchmark firehose resource consumption."
    method_option :concurrency, :type => :numeric, :default => 1, :aliases => '-c'
    def consume(uri)
      EM.run do
        options[:concurrency].times { Firehose::Client::Consumer.parse(uri).request }
      end
    end
  end
end