require 'spec_helper'

describe Firehose::Publisher do
  include EM::TestHelper

  let(:redis) do 
    # This got out of hand, but I didn't have enough time to refactor.
    double 'redis',
      :publish => EM::DefaultDeferrable.new,
      :lset => EM::DefaultDeferrable.new,
      :expire => EM::DefaultDeferrable.new,
      :ltrim => EM::DefaultDeferrable.new,
      :incr => EM::DefaultDeferrable.new,
      :multi => EM::DefaultDeferrable.new,
      :exec => EM::DefaultDeferrable.new
  end
  let(:publisher) do
    publisher = Firehose::Publisher.new
    publisher.stub(:redis => redis)
    publisher
  end
  let(:channel)   { "/firehose/publisher/test/#{Time.now.to_i}" }
  let(:message)   { "howdy friends!" }

  it "should have 10 MAX_MESSAGES" do
    Firehose::Publisher::MAX_MESSAGES.should == 10
  end

  it "should have 1 day TTL" do
    Firehose::Publisher::TTL.should == 86400
  end

  describe "#publish" do
    it "should pipeline" do
      redis.should_receive(:multi)
      redis.should_receive(:exec)
      publisher.publish(channel, message)
    end

    it "should publish message change" do
      redis.should_receive(:publish).with('firehose:channel_updates', channel)
      publisher.publish(channel, message)
    end

    it "should add message to list" do
      redis.should_receive(:lset).with("firehose:#{channel}:list", message)
      publisher.publish channel, message
    end

    it "should limit list to MAX_MESSAGES messages" do
      redis.should_receive(:ltrim).with("firehose:#{channel}:list", 0, Firehose::Publisher::MAX_MESSAGES)
      publisher.publish channel, message
    end

    it "should increment sequence" do
      redis.should_receive(:incr).with("firehose:#{channel}:sequence")
      publisher.publish channel, message
    end

    it "should set expirery on sequence and list keys" do
      redis.should_receive(:expire).with("firehose:#{channel}:sequence", Firehose::Publisher::TTL)
      redis.should_receive(:expire).with("firehose:#{channel}:list", Firehose::Publisher::TTL)
      publisher.publish(channel, "you smell")
    end
  end
end