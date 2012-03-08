require 'spec_helper'
require 'rack/test'
require 'set'

describe Push::Transport::WebSocket do
  include Push::Test::AMQP

  let(:app) { Push::Transport::WebSocket.new }

  it "should consume message" do
    messages, channel = %w[1 2 3], '/hey/there'
    ws_url = "ws://localhost:#{Push::Test::Thin::Port}#{channel}"
    received_messages = []

    em do
      Push::Test.thin(app) do |server, http|
        http = EventMachine::HttpRequest.new(ws_url).get
        http.errback  { EM.stop }
        http.stream   {|msg| received_messages.push msg }
        EM.add_timer(1) {
          messages.each {|msg|
            Push::Backend.new.publish(msg, channel)
          }
        }
      end
    end

    messages.should =~ received_messages
  end
end