module Firehose
  class Consumer
    # Unique identifier for a consumer. Note that a consumer does not map directly to
    # a user_id. In a web browser world, you might have a user with multiple tabs open,
    # so you'll went to send each users tab a seperate message stream. Consider a convention
    # such as :user_id-:guid for your application.
    attr_reader :guid

    def initialize(guid = self.class.next_guid)
      @guid = guid
    end

    # Create a subscription and subscribe to a channel.
    def subscribe_to(channel, &block)
      subscriptions[channel].subscribe(&block)
    end

    # Active subscriptions to the backend.
    def subscriptions
      @subscriptions ||= Hash.new do |subscriptions, channel|
        # Setup the hash to generate subscriptions that can delete themselves from
        # their own collection on an unsubscription event.
        subscription = Subscription.new(self, channel)
        subscription.on_unsubscribe do
          # Remove the subscription from the consumer.subscriptions 
          # list when unsubscribe.
          subscriptions.delete channel
        end
        subscriptions[channel] = subscription
      end
    end

    # Unsubscribe from all subscriptions.
    def unsubscribe
      subscriptions.values.each(&:unsubscribe)
      @on_unsubscribe.call(self) if @on_unsubscribe
    end

    # Define callback for when unsubscribe is called from the consumer.
    def on_unsubscribe(&block)
      @on_unsubscribe = block
    end

  protected
    def self.next_guid
      rand(999_999_999_999).to_s
    end
  end
end