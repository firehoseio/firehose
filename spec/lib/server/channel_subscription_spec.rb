require 'spec_helper'

describe Firehose::Server::ChannelSubscription do
  include EM::TestHelper

  let(:channel_key) { '/bears/are/mean' }
  let(:channel) do
    Firehose::Server::ChannelSubscription.new(channel_key,
                                              sequence: sequence,
                                              timeout: timeout)
  end
  let(:sequence)    { 0 }
  let(:timeout)     { nil }
  let(:message)     { 'Raaaarrrrrr!!!!' }
  let(:publisher)   { Firehose::Server::Publisher.new }

  # If you use the memoized redis and subscriber connection objects between test
  # runs, EM won't clean up connections properly, lock forever, fail all of your tests
  # and remind you that you're wasting your life fighting event machine. Go have a beer.
  before(:each) do
    Firehose::Server::ChannelSubscription.stub(:redis) { Firehose::Server.redis.connection }
    Firehose::Server::ChannelSubscription.stub(:subscriber) { Firehose::Server::Subscriber.new(Firehose::Server.redis.connection) }
  end

  def push_message
    redis_exec 'lpush', "firehose:#{channel_key}:list", message
    redis_exec 'set', "firehose:#{channel_key}:sequence", '100'
  end

  context "callbacks" do
    it "calls #on_message" do
      push_message
      em do
        expect(channel).to receive(:on_message).with(Firehose::Server::Message.new(message, 100))
        channel.next_messages.callback { em.stop }
      end
    end

    it "calls #on_subscribe" do
      expect_any_instance_of(Firehose::Server::ChannelSubscription).to receive(:on_subscribe).with({})
      em do
        channel
        em.next_tick { em.stop }
      end
    end

    it "calls #on_unsubscribe" do
      push_message
      em do
        expect(channel).to receive(:on_unsubscribe).once
        channel.next_messages.callback { em.stop }
      end
    end
  end

  describe "#next_messages" do
    it "waits for message if message was not published before subscription" do
      em do
        channel.next_messages.callback do |messages|
          msg = messages.first
          expect(msg.payload).to eql(message)
          expect(msg.sequence).to eql(1)
          em.next_tick { em.stop }
        end

        publisher.publish(channel_key, message)
      end
    end

    it "returns the latest message and sequence if no sequence is given" do
      push_message

      em do
        channel.next_messages.callback do |messages|
          msg = messages.first
          expect(msg.payload).to eql(message)
          expect(msg.sequence).to eql(100)

          # This must happen _after_ the callback runs in order to pass consistently.
          em.next_tick { em.stop }
        end
      end
    end

    context "most recent sequence" do
      let(:sequence) { 100 }

      it "waits for message if most recent sequence is given" do
        push_message

        em 3 do
          channel.next_messages.callback do |messages|
            msg = messages.first.payload
            seq = messages.first.sequence
            expect(msg).to eql(message)
            expect(seq).to eql(101)
            em.next_tick { em.stop }
          end.errback

          publisher.publish(channel_key, message)
        end
      end
    end


    context "future sequence" do
      let(:sequence) { 101 }

      it "waits for message if a future sequence is given" do
        push_message

        em 3 do
          channel.next_messages.callback do |messages|
            msg = messages.first.payload
            seq = messages.first.sequence
            expect(msg).to eql(message)
            expect(seq).to eql(101)
            em.next_tick { em.stop }
          end.errback

          publisher.publish(channel_key, message)
        end
      end
    end


    context "outdated sequence" do
      let(:sequence) { 2 }

      it "immediatly gets a message if message sequence is behind and in list" do
        messages = %w[a b c d e]

        em 3 do
          publish_messages(messages) do
            channel.next_messages.callback do |messages|
              msg = messages.first.payload
              seq = messages.first.sequence
              expect(msg).to eql('c')
              expect(seq).to eql(3)

              # This must happen _after_ the callback runs in order to pass consistently.
              em.next_tick { em.stop }
            end
          end
        end
      end
    end

    it "gets current message if sequence is really far behind in list" do
      messages = ('aa'..'zz').to_a

      em 3 do
        publish_messages(messages) do
          channel.next_messages.callback do |msgs|
            msg = msgs.last.payload
            seq = msgs.last.sequence
            expect(msg).to eql(messages.last)
            expect(seq).to eql(messages.size)

            # This must happen _after_ the callback runs in order to pass consistently.
            em.next_tick { em.stop }
          end
        end
      end
    end

    context "a timeout is set" do
      let(:sequence) { 100 }
      let(:timeout)  { 1 }

      it "times out if message isn't published in time" do
        push_message

        em 3 do
          channel.next_messages.callback do |messages|
            msg = messages.first.payload
            seq = messages.first.sequence
            raise 'test failed'
          end.errback do |e|
            expect(e).to eql(:timeout)
            em.next_tick { em.stop }
          end

          EM::add_timer(2) do
            publisher.publish(channel_key, message)
          end
        end
      end

      context "larger timeout" do
        let(:timeout)  { 2 }

        it "does not timeout if message is published in time" do
          push_message

          em 3 do
            d = channel.next_messages.callback do |messages|
              msg = messages.first.payload
              seq = messages.first.sequence
              expect(msg).to eql(message)
              expect(seq).to eql(101)
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
