require 'spec_helper'

describe Push::Backend::Bunny do
  include Push::Test::AMQP

  before(:all) do
    @consumer = Push::Consumer.new
    @backend = Push::Backend::Bunny.new
    @channel = amqp.next_channel
  end

  it "should be registered as :bunny" do
    Push::Backend::Adapters.backend(:bunny).should be_instance_of(Push::Backend::Bunny)
  end

  it "should be subscribable" do
    Push::Backend::Bunny.new.should be_subscribable
  end

  it "should be publishable" do
    Push::Backend::Bunny.new.should be_publishable
  end

  it "should publish and subscribe to a message" do
    subscription = Push::Consumer::Subscription.new(@consumer, @channel, @backend)

    @backend.publish('testing', @channel)
    @backend.subscribe(subscription) do |m|
      m.should eql('testing')
    end
  end

  context "AMQP resources" do
    before(:each) do
      @subscription = Push::Consumer::Subscription.new(@consumer, @channel, @backend)
    end

    it "should release channels" do
      lambda{
        @backend.publish('hmmmm', @channel)
        @backend.subscribe(@subscription) do |m|
          lambda{
            m.should eql('hmmmm')
          }.should change(amqp.channels, :count).by(1)
        end
        @subscription.delete
      }.should_not change(amqp.channels, :count)
    end

    it "should release exchanges" do
      lambda{
        @backend.publish('hmmmm', @channel)
        @backend.subscribe(@subscription) do |m|
          lambda{
            m.should eql('hmmmm')
          }.should change(amqp.exchanges, :count).by(1)
        end
        @subscription.delete
      }.should_not change(amqp.exchanges, :count)
    end

    it "should release queues" do
      lambda{
        @backend.publish('hmmmm', @channel)
        @backend.subscribe(@subscription) do |m|
          lambda{
            m.should eql('hmmmm')
          }.should change(amqp.queues, :count).by(1)
        end
        @subscription.delete
      }.should_not change(amqp.queues, :count)
    end
  end
end