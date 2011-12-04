require 'spec_helper'

describe Push::Backend::AMQP do
  include EM::Ventually
  
  before(:all) do
    @consumer = Push::Consumer.new
  end

  it "should publish and subscribe to a message across multiple backends" do
    Push::Backend::AMQP.connection.reconnect
    channel = '/amqp/tres'

    subscription = Push::Consumer::Subscription.new(@consumer, channel, Push::Backend::AMQP.new)
    subscription.on_message do |m|
      @test_message = m
    end
    subscription.subscribe
    EM.add_timer(1){ Push::Backend::AMQP.new.publish('sup?', channel) }
    Push::Backend::AMQP.new.publish('sup?', channel)

    ly('sup?'){ @test_message }
  end

  context "publishing" do
    before(:each) do
      @channel = '/amqp/pub'
      @subscription = Push::Consumer::Subscription.new(@consumer, @channel, Push::Backend::AMQP.new)
    end

    it "should release exchange after publish if there are no consumers waiting"
    it "should not release exchange if there's a consumer waiting for a message"
  end

  context "subscription" do
    context "deletion" do
      it "should release consumer queue"
      it "should release exchange"
    end
  end
end