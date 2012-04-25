require 'spec_helper'

describe Firehose::Client do
  let(:channel) { "/something/somewhere" }
  let(:client)  { Firehose::Client.new }

  it "should pub/sub" do
    sent, received = "Hey dude", []
    
    EM.run {
      EM.add_timer(5) { EM.stop }

      client.subscribe_to(channel) do |msg| do
        received << msg
      end

      client.subscribe_to(channel) do |msg| do
        received << msg
      end

      client.publish(sent).to(channel)
    }

    sent.should == received.first
    sent.should == received.last
  end
end