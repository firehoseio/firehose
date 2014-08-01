require 'spec_helper'

describe Firehose::Server::Subscriber do
  include EM::TestHelper

  let(:channel_key)     { '/bears/are/mean' }
  let(:subscriber)      { Firehose::Server::Subscriber.new(EM::Hiredis.connect) }
  let(:dummy_subscriber){ Firehose::Server::Subscriber.new(double('redis', :pubsub => double('pubsub', :subscribe => EM::DefaultDeferrable.new, :on => nil))) }
  let(:message)         { 'Raaaarrrrrr!!!!' }
  let(:publisher)       { Firehose::Server::Publisher.new }

  describe "#subscribe" do
    it "should add the deferrable to the subscriptions hash" do
      deferrable = EM::DefaultDeferrable.new
      dummy_subscriber.subscribe(channel_key, deferrable)
      dummy_subscriber.send(:subscriptions)[channel_key].should == [deferrable]
    end

    it "should call succeed on the deferrable when a message is published" do
      deferrable = EM::DefaultDeferrable.new
      deferrable.callback do |msg, sequence|
        msg.should == message
        sequence.should == 1 # The publisher is fresh, so the sequence ID will be 1.
        em.next_tick { em.stop }
      end

      em do
        subscriber.subscribe(channel_key, deferrable)
        publisher.publish(channel_key, message)
      end
    end

    it "shouldn't call succeed on the deferrable when a 2nd message is published" do
      deferrable = EM::DefaultDeferrable.new
      deferrable.should_receive(:succeed).with(message, 1) # The publisher is fresh, so the sequence ID will be 1.
      deferrable.should_not_receive(:succeed).with('2nd message', 2)
      em do
        subscriber.subscribe(channel_key, deferrable)
        publisher.publish(channel_key, message).callback do
          publisher.publish(channel_key, '2nd message').callback do
            em.stop
          end
        end
      end

    end
  end

  describe "#unsubscribe" do
    it "should remove the deferrable from the subscriptions hash" do
      deferrable = EM::DefaultDeferrable.new
      dummy_subscriber.subscribe(channel_key, deferrable)
      dummy_subscriber.unsubscribe(channel_key, deferrable)
      dummy_subscriber.send(:subscriptions).has_key?(channel_key).should be_falsey
    end

    it "shouldn't call succeed on the deferrable when a message is published" do
      deferrable = EM::DefaultDeferrable.new
      deferrable.should_not_receive(:succeed).with(message, 1) # The publisher is fresh, so the sequence ID will be 1.
      em do
        subscriber.subscribe(channel_key, deferrable)
        subscriber.unsubscribe(channel_key, deferrable)
        publisher.publish(channel_key, message).callback do
          em.stop
        end
      end
    end
  end
end
