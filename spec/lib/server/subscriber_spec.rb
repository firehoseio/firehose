require 'spec_helper'

describe Firehose::Server::Subscriber do
  include EM::TestHelper

  let(:channel_key)     { '/bears/are/mean' }
  let(:chan_sub)        { Firehose::Server::ChannelSubscription.new(channel_key) }
  let(:subscriber)      { Firehose::Server::Subscriber.new(Firehose::Server.redis.connection) }
  let(:dummy_subscriber){ Firehose::Server::Subscriber.new(double('redis', :pubsub => double('pubsub', :subscribe => EM::DefaultDeferrable.new, :on => nil))) }
  let(:message)         { 'Raaaarrrrrr!!!!' }
  let(:publisher)       { Firehose::Server::Publisher.new }

  describe "#subscribe" do
    it "adds the deferrable to the subscriptions hash" do
      em do
        dummy_subscriber.subscribe(chan_sub)
        expect(dummy_subscriber.send(:subscriptions)[channel_key]).to eql([chan_sub])
        em.next_tick { em.stop }
      end
    end

    it "calls process_messages on the deferrable when a message is published" do
      em do
        expect(chan_sub).to receive(:process_messages)#.with([Firehose::Server::Message.new(message, 1)])
        subscriber.subscribe(chan_sub)
        publisher.publish(channel_key, message).callback do
          em.next_tick { em.stop }
        end
      end
    end

    it "doesn't call process_messages on the deferrable when a 2nd message is published" do
      em do
        chan_sub.should_receive(:process_messages).with([Firehose::Server::Message.new(message, 1)]) # The publisher is fresh, so the sequence ID will be 1.
        chan_sub.should_not_receive(:process_messages).with([Firehose::Server::Message.new('2nd message', 2)])

        subscriber.subscribe(chan_sub)
        publisher.publish(channel_key, message).callback do
          publisher.publish(channel_key, '2nd message').callback do
            em.next_tick { em.stop }
          end
        end
      end
    end
  end

  describe "#unsubscribe" do
    it "removes the deferrable from the subscriptions hash" do
      dummy_subscriber.subscribe(chan_sub)
      dummy_subscriber.unsubscribe(chan_sub)
      expect(dummy_subscriber.send(:subscriptions).has_key?(channel_key)).to be_falsey
    end

    it "doesn't call succeed on the deferrable when a message is published" do
      deferrable = EM::DefaultDeferrable.new
      deferrable.should_not_receive(:succeed).with(message, 1) # The publisher is fresh, so the sequence ID will be 1.
      em do
        subscriber.subscribe(chan_sub)
        subscriber.unsubscribe(chan_sub)
        publisher.publish(channel_key, message).callback do
          em.next_tick { em.stop }
        end
      end
    end
  end
end
