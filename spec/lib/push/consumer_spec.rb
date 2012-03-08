require 'spec_helper'

describe Push::Consumer do
  include Push::Test::AMQP

  let(:message) { "Hi! Its #{Time.now.to_i}."}
  let(:channel) { "/exchange-#{rand(99999999)}" }
  let(:producer){ Push::Producer.new }
  let(:consumer){ Push::Consumer.new }
  let(:publish) { producer.publish(message).to(channel) }

  context "subscription" do
    it "should set channel" do
      consumer.subscription('/exchange').channel.should eql('/exchange')
    end

    it "should set consumer" do
      consumer.subscription('/exchange').consumer.should be_instance_of(Push::Consumer)
    end

    it "should set backend" do
      consumer.subscription('/exchange').backend.should be_instance_of(Push::Backend)
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

  it "should consume message" do
    receieved = nil

    em do
      consumer.subscribe(channel){|m| receieved = m }
      EM.add_timer(1){
        producer.publish(message).to(channel)
      }
    end

    message.should == receieved
  end
end