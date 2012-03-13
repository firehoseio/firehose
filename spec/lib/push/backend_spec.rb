require 'spec_helper'

# DANGER WILL ROBINSON! You're heading into event machine test code. Things
# get kind of crazy in here, and by that I mean that traditional before(:each)
# blocks don't run inside the reactor, so you're screwed if you try to setup
# EM to make it happen. Don't even try! Just use custom setup methods.

describe Push::Backend do
  include Push::Test::AMQP

  let(:backend) { Push::Backend.new }
  let(:consumer){ Push::Consumer.new }
  let(:channel) { "/backend_test/#{Time.now.to_i}" }
  let(:subscription){
    Push::Consumer::Subscription.new consumer, channel, backend
  }

  it "should publish and subscribe to a message across multiple backends" do
    sent, received = 'sup?', nil

    em do
      subscription.on_message do |m|
        received = m
      end
      subscription.subscribe

      # Dunny why yet, but we have to let this 'warm up'
      EM.add_timer(1){ backend.publish('sup?', channel) }
    end

    received.should == sent
  end

  it "should release exchange after publishing if no clients are connected" do
    exchanges_during_subscription = []
    exchanges_after_subscription = []

    Push.config.amqp.queue_ttl = 0.1

    em 5 do
      subscription.on_message do |m|
        received = m
      end
      subscription.subscribe

      # Dunny why yet, but we have to let this 'warm up'
      EM.add_timer(1){
        Push::Backend.new.publish('sup?', channel)
      }
      EM.add_timer(2){
        exchanges_during_subscription = amqp.exchanges
      }
      EM.add_timer(3){
        subscription.delete
      }
      EM.add_timer(4){
        exchanges_after_subscription = amqp.exchanges
      }
    end

    exchanges_during_subscription.find{|(e,t)| e == channel}.should_not be_nil
    exchanges_after_subscription.find{|(e,t)| e == channel}.should be_nil
  end
end