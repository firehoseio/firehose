require 'spec_helper'

describe Push::Consumer do
  before(:each) do
    Push.config.backend = :test
    @consumer = Push::Consumer.new
    @channel = Push::Consumer::Subscription.backend.channels
  end

  context "subscription" do
    before(:each) do
      @channel['/exchange'] << 'hi dude'
    end

    it "should consume message" do
      lambda{
        @consumer.subscribe('/exchange') do |m|
          m.should eql('hi dude')
        end
      }.should change(@channel['/exchange'], :count).by(-1)
    end

    it "should set channel" do
      @consumer.subscribe('/exchange').channel.should eql('/exchange')
    end

    it "should set consumer" do
      @consumer.subscribe('/exchange').consumer.should be_instance_of(Push::Consumer)
    end

    it "should set backend" do
      @consumer.subscribe('/exchange').backend.should eql(Push::Consumer::Subscription.backend)
    end
  end

  it "should have a consumer id" do
    consumer = Push::Consumer.new do |c|
      c.id = 100
    end
    consumer.id.should eql(100)
  end

  it "should have an awesome consumer_id generator" do
    Push::Consumer.new.id.should be_instance_of(String)
  end
end