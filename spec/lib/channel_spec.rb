require 'spec_helper'

describe Firehose::Channel do
  include EM::TestHelper

  let(:channel_key)     { '/bears/are/mean' }
  let(:channel)         { Firehose::Channel.new(channel_key, EM::Hiredis.connect, subscriber) }
  let(:subscriber)      { Firehose::Channel::Subscriber.new(EM::Hiredis.connect) }
  let(:message)         { 'Raaaarrrrrr!!!!' }
  let(:publisher)       { Firehose::Publisher.new }

  describe "#next_message" do
    it "should wait for message if message was not published before subscription" do
      em do
        channel.next_message.callback do |msg, seq|
          msg.should == message
          seq.should == 1
          em.stop
        end

        publisher.publish(channel_key, message)
      end
    end

    it "should return the latest message and sequence if no sequence is given" do
      redis_exec 'lpush', "firehose:#{channel_key}:list", message
      redis_exec 'set', "firehose:#{channel_key}:sequence", '100'

      em do
        channel.next_message.callback do |msg, seq|
          msg.should == message
          seq.should == 100
          em.stop
        end
      end
    end

    it "should wait for message if most recent sequence is given" do
      em 3 do
        channel.next_message.callback do |msg, seq|
          msg.should == message
          seq.should == 1
          em.stop
        end.errback

        publisher.publish(channel_key, message)
      end
    end

    it "should immediatly get a message if message sequence is behind and in list" do
      messages = %w[a b c d e]

      em 3 do
        messages.each do |msg|
          publisher.publish(channel_key, msg)
        end

        channel.next_message(2).callback do |msg, seq|
          msg.should == 'b'
          seq.should == 3
          em.stop
        end
      end
    end

    it "should get current message if sequence is really far behind in list" do
      messages = %w[a b c d e f g h i j k l m n o p q r s t u v x y z]

      em 3 do
        messages.each do |msg|
          publisher.publish(channel_key, msg)
        end

        channel.next_message(2).callback do |msg, seq|
          msg.should == messages.last
          seq.should == messages.size
          em.stop
        end
      end
    end
  end
end