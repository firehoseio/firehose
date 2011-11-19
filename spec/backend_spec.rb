require 'spec_helper'

describe Push::Backend::Base do
  it "should be subscribable" do
    Push::Backend::Base.new.should be_subscribable
  end

  it "should be publishable" do
    Push::Backend::Base.new.should be_publishable
  end
end

describe Push::Backend::Test do
  before(:all) do
    @backend = Push::Backend::Test.new
  end

  it "should be subscribable" do
    @backend.should be_subscribable
  end

  it "should be publishable" do
    @backend.should be_publishable
  end

  it "should publish messages" do
    lambda{
      @backend.publish('hi', '/1', '/2')
    }.should change(@backend.channel, :size).by(2)
  end

  it "should subscribe to messages" do
    lambda{
      @backend.subscribe('/1', '/2') do |m|
        m.should eql('hi')
      end
    }.should change(@backend.channel, :size).by(-2)
  end

  it "should not return anything or block if no messages are in the queue" do
    @backend.subscribe('/1') do |m|
      m.should be_nil
    end
  end
end