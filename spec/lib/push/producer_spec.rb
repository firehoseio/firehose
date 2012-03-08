require 'spec_helper'

describe Push::Producer do
  include Push::Test::AMQP

  let(:message) { "Hi! Its #{Time.now.to_i}."}
  let(:channel) { "/exchange-#{rand(99999999)}" }
  let(:producer){ Push::Producer.new }
  let(:consumer){ Push::Consumer.new }
  let(:publish) { producer.publish(message).to(channel) }

  it "should publish" do
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