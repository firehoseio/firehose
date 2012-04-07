require 'spec_helper'
require 'rack/test'
require 'set'

describe Push::Transport::WebSocket do
  include Push::Test::AMQP

  let(:app) { Push::Transport::WebSocket.new }

  it "should consume message" do
    sent, channel = (1..500).map(&:to_s), '/hey/there'
    ws_url = "ws://localhost:#{Push::Test::Thin::Port}#{channel}"
    received = []

    em do
      Push::Test.thin(app) do |http|
        http = EventMachine::HttpRequest.new(ws_url).get
        http.errback  { EM.stop }
        http.stream   {|msg| received.push msg }
        EM.add_timer(1) {
          sent.each {|msg|
            Push::Backend.new.publish(msg, channel)
          }
        }
      end
    end

    sent.should include(received)
  end
end