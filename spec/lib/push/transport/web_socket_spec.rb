require 'spec_helper'
require 'rack/test'

describe Push::Transport::WebSocket do
  include EM::Ventually
  include Push::Logging

  before(:each) do
    Push.config.backend = :amqp
  end

  def app
    Push::Transport::WebSocket.new do |c|
      # c.consumer do |env| # Extract out a session_id here. Could be from a cookie or a header.
      #   Push::Consumer.new env['X_HTTP_CONSUMER_ID']
      # end
    end
  end

  it "should consume message" do
    messages, channel = %w[1 2 3], '/hey/there'
    ws_url = "ws://localhost:#{Push::Test::Thin::Port}#{channel}"
    received_messages = []

    Push::Test.thin(app) do |server, http|
      http = EventMachine::HttpRequest.new(ws_url).get :timeout => 0
      http.errback { puts "oops" }
      http.callback {
        puts "WebSocket connected!"
      }
      http.stream {|msg|
        received_messages << msg
      }
      EM.add_timer(1) {
        messages.each {|msg|
          Push.config.backend.publish(msg, channel)
        }
      }
    end

    ly(messages){ received_messages }
  end
end