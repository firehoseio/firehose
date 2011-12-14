require 'spec_helper'
require 'rack/test'
require 'set'

describe Push::Transport::WebSocket do
  include EM::Ventually
  include Push::Logging

  before(:each) do
    Push.config.backend = :amqp
  end

  def app
    Push::Transport::WebSocket.new
  end

  it "should consume message" do
    Push::Backend::AMQP.connection.reconnect
    messages, channel = %w[1 2 3], '/hey/there'
    ws_url = "ws://localhost:#{Push::Test::Thin::Port}#{channel}"
    received_messages = []

    Push::Test.thin(app) do |server, http|
      http = EventMachine::HttpRequest.new(ws_url).get :timeout => 0
      http.errback  { raise }
      http.callback { }
      http.stream   {|msg| received_messages << msg }
      EM.add_timer(1) {
        messages.each {|msg|
          Push::Backend::AMQP.new.publish(msg, channel)
        }
      }
    end

    ly { messages }.test{ |v| Set.new(messages) == Set.new(received_messages) }
  end
end