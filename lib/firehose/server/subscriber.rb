module Firehose
  module Server
    # Setups a connetion to Redis to listen for new resources...
    class Subscriber
      attr_reader :pubsub

      def initialize(redis)
        @pubsub = redis.pubsub
        # TODO: Instead of just raising an exception, it would probably be better
        #       for the errback to set some sort of 'disconnected' state. Then
        #       whenever a deferrable was 'subscribed' we could instantly fail
        #       the deferrable with whatever connection error we had.
        #       An alternative which would have a similar result would be to
        #       subscribe lazily (i.e. not until we have a deferrable to subscribe).
        #       Then, if connecting failed, it'd be super easy to fail the deferrable
        #       with the same error.
        #       The final goal is to allow the failed deferrable bubble back up
        #       so we can send back a nice, clean 500 error to the client.
        channel_updates_key = Server.key('channel_updates')
        pubsub.subscribe(channel_updates_key).
          errback{|e| EM.next_tick { raise e } }.
          callback { Firehose.logger.debug "Redis subscribed to `#{channel_updates_key}`" }
        pubsub.on(:message) do |_, payload|
          channel_key, channel_sequence, message = Server::Publisher.from_payload(payload)
          messages = [ MessageBuffer::Message.new(message, channel_sequence.to_i) ]
          if deferrables = subscriptions.delete(channel_key)
            Firehose.logger.debug "Redis notifying #{deferrables.count} deferrable(s) at `#{channel_key}` with channel_sequence `#{channel_sequence}` and message `#{message}`"
            deferrables.each do |deferrable|
              Firehose.logger.debug "Sending message #{message} and channel_sequence #{channel_sequence} to client from subscriber"
              deferrable.succeed messages
            end
          end
        end
      end

      def subscribe(channel_key, deferrable)
        subscriptions[channel_key].push deferrable
      end

      def unsubscribe(channel_key, deferrable)
        subscriptions[channel_key].delete deferrable
        subscriptions.delete(channel_key) if subscriptions[channel_key].empty?
      end

      private
      def subscriptions
        @subscriptions ||= Hash.new{|h,k| h[k] = []}
      end
    end
  end
end
