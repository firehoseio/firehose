require 'spec_helper'

# DANGER WILL ROBINSON! You're heading into event machine test code. Things
# get kind of crazy in here, and by that I mean that traditional before(:each)
# blocks don't run inside the reactor, so you're screwed if you try to setup
# EM to make it happen. Don't even try! Just use custom setup methods.

describe Push::Backend::AMQP do
  include EM::Ventually
  include Push::Test::AMQP

  before(:all) do
    Push.config.amqp.queue_ttl = 0
  end

  def setup
    Push::Backend::AMQP.connection.reconnect
    @backend = Push::Backend::AMQP.new
    @consumer = Push::Consumer.new
    @channel = amqp.next_channel
  end

  def setup_subscription
    @subscription = Push::Consumer::Subscription.new @consumer, @channel, @backend
  end

  it "should publish and subscribe to a message across multiple backends" do
    setup
    setup_subscription
    @subscription.on_message do |m|
      @test_message = m
    end
    @subscription.subscribe

    # Dunny why yet, but we have to let this 'warm up'
    EM.add_timer(1){ Push::Backend::AMQP.new.publish('sup?', @channel) }
    Push::Backend::AMQP.new.publish('sup?', @channel)
    ly('sup?'){ @test_message }
  end

  # context "AMQP" do
  #   context "publishing" do
  #     context "with a waiting consumer" do
  #       it "should release channel" do
  #         setup
  #         count = amqp.channels.count
  #         setup_subscription

  #         @backend.publish 'oh me...', @channel
  #         @backend.publish 'oh my!', @channel
  #         # 2 more because the consumer and publisher are connected
  #         ly(count + 2){ amqp.channels.count }
  #       end

  #       it "should release connection channel references" do
  #         setup
  #         count = @backend.connection.channels.count
  #         setup_subscription

  #         @backend.publish 'oh me...', @channel
  #         @backend.publish 'oh my!', @channel
  #         # 2 more because the consumer and publisher are connected
  #         ly(count + 2){ @backend.connection.channels.count }
  #       end

  #       it "should not release exchange" do
  #         setup
  #         count = amqp.exchanges.count
  #         setup_subscription

  #         @backend.publish 'oh me...', @channel
  #         @backend.publish 'oh my!', @channel

  #         ly{ amqp.exchanges }.test do |exchanges|
  #           exchanges.any? {|exchange| exchange == @channel }
  #         end
  #       end
  #     end

  #     context "without a waiting consumer" do
  #       it "should release channel" do
  #         setup
  #         count = amqp.channels.count
  #         @backend.publish 'woohoo!', @channel
  #         ly(count){ @backend.connection.channels.count }
  #       end

  #       it "should release exchange" do
  #         setup
  #         @backend.publish 'woohoo!', @channel
  #         # Make sure the exchang ceases to exist
  #         ly{ amqp.exchanges }.test do |exchanges|
  #           exchanges.none? {|exchange| exchange == @channel }
  #         end
  #       end
  #     end
  #   end

  #   context "subscription" do
  #     it "should release queue" do
  #       count = amqp.queues.count
  #       setup
  #       setup_subscription

  #       @subscription.delete
  #       ly(count){ amqp.queues.count }
  #     end

  #     it "should release exchange" do
  #       count = amqp.exchanges.count
  #       setup
  #       setup_subscription

  #       @subscription.delete
  #       ly(count){ amqp.exchanges.count }
  #     end

  #     it "should release channel" do
  #       count = amqp.channels.count
  #       setup
  #       setup_subscription

  #       @subscription.delete
  #       ly(count){ amqp.channels.count }
  #     end

  #     it "should release connection channel references" do
  #       setup
  #       setup_subscription
  #       count = @backend.connection.channels.count

  #       @subscription.delete
  #       ly(count - 1){ @backend.connection.channels.count }
  #     end
  #   end
  # end
end