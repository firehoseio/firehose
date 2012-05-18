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

          # This must happen _after_ the callback runs in order to pass consistently.
          EM.next_tick { em.stop }
        end
      end
    end

    it "should wait for message if most recent sequence is given" do
      redis_exec 'lpush', "firehose:#{channel_key}:list", message
      redis_exec 'set', "firehose:#{channel_key}:sequence", '100'

      em 3 do
        channel.next_message(100).callback do |msg, seq|
          msg.should == message
          seq.should == 101
          em.stop
        end.errback

        publisher.publish(channel_key, message)
      end

    end

    it "should immediatly get a message if message sequence is behind and in list" do
      messages = %w[a b c d e]

      em 3 do
        publish_messages(messages) do
          channel.next_message(2).callback do |msg, seq|
            msg.should == 'c'
            seq.should == 3

            # This must happen _after_ the callback runs in order to pass consistently.
            EM.next_tick { em.stop }
          end
        end
      end
    end

    it "should get current message if sequence is really far behind in list" do
      messages = ('a'..'z').to_a

      em 3 do
        publish_messages(messages) do
          channel.next_message(2).callback do |msg, seq|
            msg.should == messages.last
            seq.should == messages.size

            # This must happen _after_ the callback runs in order to pass consistently.
            EM.next_tick { em.stop }
          end
        end
      end
    end

    context "a timeout is set" do
      it "should timeout if message isn't published in time" do
        redis_exec 'lpush', "firehose:#{channel_key}:list", message
        redis_exec 'set', "firehose:#{channel_key}:sequence", '100'

        em 3 do
          channel.next_message(100, :timeout => 1).callback do |msg, seq|
            raise 'test failed'
          end.errback do |e|
            e.should == :timeout
            em.stop
          end

          EM::add_timer(2) do
            publisher.publish(channel_key, message)
          end
        end
      end

      it "should not timeout if message is published in time" do
        redis_exec 'lpush', "firehose:#{channel_key}:list", message
        redis_exec 'set', "firehose:#{channel_key}:sequence", '100'

        em 3 do
          d = channel.next_message(100, :timeout => 2).callback do |msg, seq|
            msg.should == message
            seq.should == 101
            EM::add_timer(1) do
              em.stop
            end
          end.errback do |e|
            raise 'test failed'
          end

          d.should_not_receive(:fail)

          EM::add_timer(1) do
            publisher.publish(channel_key, message)
          end
        end
      end
    end
  end


  # Publishes the given messages and executes the given block when finished.
  def publish_messages(all_messages)
    publish = Proc.new do |messages_to_publish|
      msg = messages_to_publish.shift
      publisher.publish(channel_key, msg).callback do
        if messages_to_publish.empty?
          # Publishing is done, proceed with the test
          yield
        else
          # Publish the next message
          publish.call messages_to_publish
        end
      end
    end

    publish.call all_messages.dup
  end
end
