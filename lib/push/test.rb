require 'thin'
require 'em-http-request'

# Boot our thins on this port for long poll testing
module Push
  module Test
    # Fire up a thin server, do some stuff, then kill it
    def self.thin(app, host=Push::Test::Thin::Host, port=Push::Test::Thin::Port, &block)
      server = ::Thin::Server.new(app, host, port)
      server.log_file = Push.logger # Shhhh
      server.start
      EM.next_tick{
        block.call server, Thin::RequestHelper.new("http://#{host}:#{port}")
      }
    end

    module Thin
      class RequestHelper
        attr_accessor :root_url

        def initialize(root_url)
          @root_url = root_url
        end

        # Built out a method per HTTP request type
        %w[get put post delete head].each do |http_method|
          class_eval %{
            def #{http_method}(path, opts={}, &block)
              request(:#{http_method}, path, opts={}, &block)
            end
          }
        end

      private
        def request(method, path, opts={}, &block)
          http = EventMachine::HttpRequest.new(uri(path)).send(method, opts) # get(opts) ...
          # Wire up the callbacks, raise an exception if there's a connection error
          http.callback { block.call(http) }
          http.errback  { 
            raise "Connection Error: #{http.inspect}"
            EM.stop
          }
        end

        def uri(path)
          [root_url, path].join
        end
      end

      Port = 9080
      Host = '0.0.0.0'
    end
  end
end