require 'spec_helper'

describe Firehose::Channel do
  include EM::TestHelper

  let(:channel_key)     { '/bears/are/mean' }
  let(:channel)         { Firehose::Channel.new(channel_key, EM::Hiredis.connect, subscriber) }
  let(:subscriber)      { Firehose::Channel::Subscriber.new(EM::Hiredis.connect) }
  let(:message)         { 'Raaaarrrrrr!!!!' }
  let(:publisher)       { Firehose::Publisher.new }

  describe "#next_message" do

    it "should return the latest message and sequence if no sequence number is given" do
      redis_exec 'lpush', "firehose:#{channel_key}:list", message
      redis_exec 'set', "firehose:#{channel_key}:sequence", '100'

      em do
        channel.next_message.callback do |msg, seq|
          msg.should == message
          seq.should == '100'

          em.stop
        end
      end

    end

    it "should chillax and wait for a message to come through the subscription if its not in the list" do
      redis_exec 'set', "firehose:#{channel_key}:sequence", '100'

      em 3 do
        channel.next_message.callback do |msg, seq|
          msg.should == message
          seq.should == '101'
          em.stop
        end.errback

        publisher.publish(channel_key, message)
      end
    end
  end
end