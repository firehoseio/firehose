require 'spec_helper'

describe Push::Backend::AMQP do
  include EM::Ventually
  
  before(:all) do
    @consumer = Push::Consumer.new
  end

  it "should publish and subscribe to a message across multiple backends" do
    Push::Backend::AMQP.connection.reconnect
    channel = '/amqp/tres'

    subscription = Push::Consumer::Subscription.new(@consumer, channel, Push::Backend::AMQP.new)
    subscription.on_message do |m|
      @test_message = m
    end
    subscription.subscribe
    EM.add_timer(1){ Push::Backend::AMQP.new.publish('sup?', channel) }
    Push::Backend::AMQP.new.publish('sup?', channel)

    ly('sup?'){ @test_message }
  end
  
  context "when there is a consumer waiting" do
    def setup_consumer
      @channel = '/amqp/foo'
      
      @subscription = Push::Consumer::Subscription.new @consumer,
        @channel, Push::Backend::AMQP.new
      
      @subscription.backend.connection.reconnect
      @subscription.subscribe
    end
    
    it "should not release the exchange after publishing" do
      setup_consumer
      old_count = count_exchanges
      Push::Backend::AMQP.new.publish 'oh hey', @channel
      ly(old_count){ count_exchanges }
    end
    
    after(:all) do
      @subscription.delete if @subscription
    end
  end
  
  it "should release exchange after publish if there are no consumers waiting"

  context "subscription" do
    context "deletion" do
      it "should release consumer queue"
      it "should release exchange"
    end
  end
end

def count_exchanges
  %x{ rabbitmqctl -q list_exchanges }.split(/\n/).length
end

def print_exchanges
  result = %x{ rabbitmqctl -q list_exchanges }
  puts "\n\nexchanges:\n#{result}\n"
end
