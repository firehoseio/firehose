require 'spec_helper'
require 'em-ventually/rspec'

describe Push::Backend::AMQP do
  before(:all) do
    @consumer = Push::Consumer.new
  end

  # it "should be registered as :amqp" do
  #   Push::Backend.adapter(:amqp).should be_instance_of(Push::Backend::AMQP)
  # end

  # it "should be subscribable" do
  #   Push::Backend::AMQP.new.should be_subscribable
  # end

  # it "should be publishable" do
  #   Push::Backend::AMQP.new.should be_publishable
  # end

  it "should publish and subscribe to a message across multiple backends" do
    pub = Push::Backend::AMQP.new
    sub = Push::Backend::AMQP.new
    channel = '/amqp/1'
    subscription = Push::Consumer::Subscription.subscribe(@consumer, channel, sub)
    test_message = nil

    subscription.on_message do |m|
      subscription.delete
      test_message = m
    end

    # TODO - This hack "just works", but doesn't make sense. Am I missing a
    # callback that I should fire off for EM connects to a queue? I think that
    # this one second delay is approx how long it takes for EM to setup the
    # subscription above and 
    EM.add_timer(1) { pub.publish('sup?', channel) }

    ly('sup?', :total => 2){ test_message }
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