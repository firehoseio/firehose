require 'spec_helper'

describe "Push amqp resources" do

  let(:channel) { "/resource-test-#{Time.now.to_i}" }

  it "should clean up exchanges and queues" do
    sent, received = 'howdy!', nil
    
    before_exchange_count = `rabbitmqctl list_exchanges`.lines.count
    before_queue_count    = `rabbitmqctl list_queues`.lines.count

    during_exchange_count = nil
    during_queue_count    = nil

    EM.run do
      # Kill test if it runs longer than 5s
      EM.add_timer(5) { EM.stop }

      subscription = Push::Subscription.new
      subscription.ttl = 1

      subscription.subscribe channel do |payload|
        received = payload
        subscription.unsubscribe

        during_exchange_count = `rabbitmqctl list_exchanges`.lines.count
        during_queue_count = `rabbitmqctl list_queues`.lines.count

        # I wait 1 second before killing em so that unsubscribe
        # can talk to AMQP before the whole thing dies.
        EM.add_timer(1){ EM.stop }
      end

      # Let the subscriber subscribe before publishing messages.
      EM.add_timer(1){ Push::Publisher.new.publish(channel, sent) }
    end

    after_exchange_count = `rabbitmqctl list_exchanges`.lines.count
    after_queue_count =    `rabbitmqctl list_queues`.lines.count

    received.should == sent

    after_exchange_count.should == before_exchange_count
    after_queue_count.should    == before_queue_count

    during_exchange_count.should == before_exchange_count + 1
    during_queue_count.should    == before_queue_count + 1
  end
end