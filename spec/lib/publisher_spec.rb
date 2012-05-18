require 'spec_helper'

describe Firehose::Publisher do
  include EM::TestHelper

  let(:publisher)   { Firehose::Publisher.new }
  let(:channel_key) { "/firehose/publisher/test/#{Time.now.to_i}" }
  let(:message)     { "howdy friends!" }

  it "should have 100 MAX_MESSAGES" do
    Firehose::Publisher::MAX_MESSAGES.should == 100
  end

  it "should have 1 day TTL" do
    Firehose::Publisher::TTL.should == 86400
  end

  describe "#publish" do
    it "should pipeline" do
      pending "Get rid of stubs"
    end

    it "should publish message change" do
      em do
        hiredis = EM::Hiredis.connect
        hiredis.subscribe "firehose:channel_updates"
        hiredis.on(:message) {|_, msg|
          msg.should == "#{channel_key}\n1\n#{message}"
          em.stop
        }
        Firehose::Publisher.new.publish channel_key, message
      end
    end

    it "should add message to list" do
      em do
        Firehose::Publisher.new.publish(channel_key, message).callback { em.stop }
      end
      redis_exec('lpop', "firehose:#{channel_key}:list").should == message
    end

    it "should limit list to MAX_MESSAGES messages" do
      em do
        Firehose::Publisher::MAX_MESSAGES.times do |n|
          publisher.publish(channel_key, message)
        end
        publisher.publish(channel_key, message).callback { em.stop }
      end
      redis_exec('llen', "firehose:#{channel_key}:list").should == Firehose::Publisher::MAX_MESSAGES
    end

    it "should increment sequence" do
      pending 'need to get public retry logic working'
      sequence_key = "firehose:#{channel_key}:sequence"

      redis_exec('get', sequence_key).should be_nil
      em do
        publisher.publish(channel_key, message).callback
        publisher.publish(channel_key, message).callback { em.stop }
      end
      redis_exec('get', sequence_key).to_i.should == 2
    end

    it "should set expirery on sequence and list keys" do
      pending "Get rid of stubs"
      # hiredis.should_receive(:expire).with("firehose:#{channel_key}:sequence", Firehose::Publisher::TTL)
      # hiredis.should_receive(:expire).with("firehose:#{channel_key}:list", Firehose::Publisher::TTL)
      # publisher.publish(channel_key, "you smell")
    end
  end
end
