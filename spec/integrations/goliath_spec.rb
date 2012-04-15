require 'spec_helper'
require 'goliath'
require 'em-http'

describe Firehose::Goliath do
  let(:app)       { Firehose::Goliath::App.new }
  let(:messages)  { (1..1000).map(&:to_s) }
  let(:channel)   { "/firehose/integration/#{Time.now.to_i}" }
  let(:uri)       { URI.parse('http://127.0.0.1:9876') }
  let(:url)       { "#{uri}#{channel}" }
  let(:cid)       { "client-#{Time.now.to_i}" }

  it "should pub-sub" do
    outgoing, received = messages.dup, []

    Goliath.env = :production
    server = Goliath::Server.new
    server.address  = uri.host
    server.port     = uri.port
    server.api      = app
    server.app      = Goliath::Rack::Builder.build(Firehose::Goliath::App, server.api)
    server.logger   = Log4r::Logger.new('goliath')

    server.start do
      EM.add_timer(30) { EM.stop } # Stop the server no matter what happens.

      publish = Proc.new do
        http = EM::HttpRequest.new(url).put(:body => outgoing.pop)
        http.errback  { EM.stop }
        http.callback { publish.call unless outgoing.empty? }
      end

      subscribe = Proc.new do
        http = EM::HttpRequest.new(url).get(:query => {'cid' => cid})
        http.errback { EM.stop }
        http.callback do
          received << http.response
          if received.size < messages.size
            subscribe.call
          else
            EM.stop
          end
        end
      end

      # Start the subscriber.
      subscribe.call

      # Wait a sec to let our subscribe setup.
      EM.add_timer(1){ publish.call }
    end

    received.should =~ messages
  end
end