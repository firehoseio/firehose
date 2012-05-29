require 'thor'

module Firehose
  class CLI < Thor
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
  end
end
