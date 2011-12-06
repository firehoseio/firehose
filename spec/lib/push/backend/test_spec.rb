require 'spec_helper'

describe Push::Backend::Test do
  before(:each) do
    @backend = Push::Backend::Test.new
  end

  it "should be registered as :test" do
    Push::Backend::Adapters.backend(:test).should be_instance_of(Push::Backend::Test)
  end

  it "should be subscribable" do
    @backend.should be_subscribable
  end

  it "should be publishable" do
    @backend.should be_publishable
  end

  it "should publish messages" do
    lambda{
      @backend.publish('hi', '/1')
    }.should change(@backend.channels, :size).by(1)
  end

  context "subscriptions" do
    before(:each) do
      @subscription = Push::Consumer::Subscription.new(Push::Consumer.new, '/1', @backend)
    end

    it "should subscribe to messages" do
      @backend.publish('hi', '/1')
      lambda{
        @backend.subscribe(@subscription)
        @subscription.on_message do |m, s|
          m.should eql('hi')
        end
      }.should change(@backend.channels['/1'], :size).by(-1)
    end

    it "should not return anything or block if no messages are in the queue" do
      @backend.subscribe(@subscription)
      @subscription.on_message do |m, s|
        m.should be_nil
        s.should eql(@subscription)
      end
    end

    it "should delete message array when subscription is deleted" do
      @backend.subscribe(@subscription)
      lambda{
        @subscription.delete
      }.should change(@backend.channels, :size).by(-1)
    end
  end
end