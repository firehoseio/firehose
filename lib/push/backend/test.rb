module Push::Backend
  # This backend is great for testing in a synchronous environment including rspec/unit/etc. You can assert
  # if a message is pushed on the queue by looking at the channels hash.
  class Test
    include PubSub

    def publish(message, channel)
      channels[channel] << message
    end

    # Loop through everything until its all out of the array. The key here is not to block because
    # we want to test pubsub in a sync environment to keep things sane
    def subscribe(subscription)
      # Kill the channel once all of the messages are out of it. This simulates the cleaning up
      # of a message exchange
      subscription.on_delete do
        channels.delete subscription.channel
      end

      # Loop through the array and pop off all the messages in the subscription. If 
      # nothing is hit in the loop, don't block and continue processing.
      while message = channels[subscription.channel].pop do
        subscription.process_message message
      end
    end

    # The key of this hash corresponds to a channel on the backend. The value of the hash is an array
    # of messages on the channel.
    def channels
      @channels ||= Hash.new {|h,k| h[k] = []} # Default hash empty hash values with an array (instead of nil)
    end
  end
end