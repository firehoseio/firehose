require 'spec_helper'

describe Firehose::Server::Publisher do
  include EM::TestHelper

  let(:publisher)   { Firehose::Server::Publisher.new }
  let(:channel_key) { "/firehose/publisher/test/#{Time.now.to_i}" }
  let(:message)     { "howdy friends!" }

  it "has 1 day TTL" do
    expect(Firehose::Server::Publisher::TTL).to eql(86400)
  end

  describe "#publish" do
    it "publishes message change" do
      em do
        hiredis = EM::Hiredis.connect.pubsub
        hiredis.subscribe "firehose:channel_updates"
        hiredis.on(:message) {|_, msg|
          expect(msg).to eql("#{channel_key}\n1\n#{message}")
          em.next_tick { em.stop }
        }
        Firehose::Server::Publisher.new.publish channel_key, message
      end
    end

    "\"'\r\t\n!@\#$%^&*()[]\v\f\a\b\e{}/=?+\\|".each_char do |char|
      it "publishes messages with the '#{char.inspect}' character" do
        msg = [char, message, char].join
        em 1 do
          Firehose::Server::Publisher.new.publish(channel_key, msg).callback { em.stop }
        end
        expect(redis_exec('lpop', "firehose:#{channel_key}:list")).to eql(msg)
      end
    end

    it "adds message to list" do
      em do
        Firehose::Server::Publisher.new.publish(channel_key, message).callback { em.stop }
      end
      expect(redis_exec('lpop', "firehose:#{channel_key}:list")).to eql(message)
    end

    it "limits list to DEFAULT_SIZE messages" do
      em do
        Firehose::Server::MessageBuffer::DEFAULT_SIZE.times do |n|
          publisher.publish(channel_key, message)
        end
        publisher.publish(channel_key, message).callback { em.stop }
      end
      expect(redis_exec('llen', "firehose:#{channel_key}:list")).to eql(Firehose::Server::MessageBuffer::DEFAULT_SIZE)
    end

    it "limits message list to a custom buffer size" do
      buffer_size = rand(100)
      em do
        Firehose::Server::MessageBuffer::DEFAULT_SIZE.times do |n|
          publisher.publish(channel_key, message)
        end
        publisher.publish(channel_key, message, buffer_size: buffer_size).callback { em.stop }
      end
      redis_exec('llen', "firehose:#{channel_key}:list").should == buffer_size
    end

    it "increments sequence" do
      sequence_key = "firehose:#{channel_key}:sequence"

      @done_counter = 0
      expect(redis_exec('get', sequence_key)).to be_nil
      em do
        publisher.publish(channel_key, message).callback { @done_counter += 1; em.next_tick { em.stop } if @done_counter > 1 }
        publisher.publish(channel_key, message).callback { @done_counter += 1; em.next_tick { em.stop } if @done_counter > 1 }
      end
      expect(redis_exec('get', sequence_key).to_i).to eql(2)
    end

    it "sets expiry on sequence and list keys" do
      ttl = 78 # Why 78? Why not!

      em do
        publisher.publish(channel_key, message, :ttl => 78).callback do
          # Allow for 1 second of slippage/delay
          expect(redis_exec('TTL', "firehose:#{channel_key}:sequence")).to be > (ttl- 1)
          expect(redis_exec('TTL', "firehose:#{channel_key}:list")).to be > (ttl - 1)
          em.stop
        end
      end
    end

  end
end
