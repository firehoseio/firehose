module Firehose
  class Broker
    def initialize
    end

    def consumers
      @consumers ||= Hash.new do |consumers, consumer_id|
        consumer = Firehose::Consumer.new(consumer_id)
        consumer.on_unsubscribe do
          consumers.delete consumer_id
        end
        consumers[consumer_id] = consumer
      end
    end

    # Don't like the [] syntax to get at consumers? No worries mate!
    def consumer(consumer_id)
      consumers[consumer_id]
    end

    # Gracefully unsubscribe all of the consumers and get rid of them from the consumers 
    # collection.
    def stop
      consumers.values.each(&:unsubscribe)
    end

    # Returns a hash of the connected consumers with the number of their subscriptions
    def stats
      consumers.inject({}) do |memo, (consumer_id, consumer)|
        memo[consumer_id] = { 'subscriptions' => consumer.subscriptions.keys }
        memo
      end
    end
  end
end