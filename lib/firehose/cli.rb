require 'thor'
require 'eventmachine'
require 'uri'

# Enable native 
EM.kqueue if EM.kqueue?
EM.epoll  if EM.epoll?

module Firehose
  class CLI < Thor
    def initialize(*args)
      super
      # Disable buffering to $stdio for Firehose.logger
      $stdout.sync = true
    end

    desc "version", "Display the current version."
    def version
      puts %[Firehose #{Firehose::VERSION} "#{Firehose::CODENAME}"]
    end

    desc "server", "Start an instance of a server."
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

    desc "consume URI", "Consume messages from a resource."
    method_option :concurrency, :type => :numeric, :default => 1, :aliases => '-c'
    def consume(uri)
      EM.run do
        options[:concurrency].times { Firehose::Client::Consumer.parse(uri).request }
      end
    end

    desc "publish URI [PAYLOAD]", "Publish messages to a resource."
    method_option :interval, :type => :numeric, :aliases => '-i'
    method_option :times, :type => :numeric, :aliases => '-n'
    def publish(uri, payload=nil)
      payload     ||= $stdin.read
      client      = Firehose::Producer.new(uri)
      path        = URI.parse(uri).path
      times       = options[:times]

      EM.run do
        # TODO I think this can be cleaned up so the top-level if/else can be ditched.
        if interval = options[:interval]
          # Publish messages at a forced interval.
          EM.add_periodic_timer interval do 
            client.publish(payload).to(path)
            EM.stop if times && (times-=1).zero?
          end
        else
          # Publish messages as soon as the last message was published.
          worker = Proc.new do
            client.publish(payload).to(path)
            times && (times-=1).zero? ? EM.stop : worker.call
          end
          worker.call
        end
      end
    end

  end
end