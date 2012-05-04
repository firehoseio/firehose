require 'spec_helper'

describe Firehose::Consumer do
  include EM::TestHelper

  let(:consumer)  { Firehose::Consumer.new }
  let(:publisher) { Firehose::Publisher.new }
  let(:channel)   { '/papa-smurf' }
  let(:another_channel)  { '/mama-smurf' }

  describe "subscriptions" do
    it "should subscribe to channel" do
      sent, recieved = 'hi', nil

      em do
        consumer.subscribe_to channel do |msg|
          recieved = msg
          em.stop
        end
        em.add_timer(1) do
          publisher.publish(channel, sent)
        end
      end

      recieved.should == sent
    end

    it "should track subscriptions" do
      lambda{
        em do
          consumer.subscribe_to channel
          consumer.subscribe_to another_channel
          em.add_timer(1){ em.stop }
        end
      }.should change{ consumer.subscriptions.size }.by(2)
    end

    it "should only allow one subscription per channel" do
      lambda{
        em do
          3.times { consumer.subscribe_to channel }
          em.add_timer(1){ em.stop }
        end
      }.should change{ consumer.subscriptions.size }.by(1)
    end

    it "should unsubscribe from all channels" do
      subscribed_count, after_unsubscribe_count = 0, nil

      em do
        consumer.subscribe_to channel
        consumer.subscribe_to another_channel
        subscribed_count = consumer.subscriptions.size
        em.add_timer(1) do 
          consumer.unsubscribe
          em.add_timer(1) do 
            em.stop
          end
        end
      end

      subscribed_count.should == 2
      consumer.subscriptions.size.should == 0
    end
  end
end