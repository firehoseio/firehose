module Firehose
  module Server
    # Connects to a specific channel on Redis and listens for messages to notify subscribers.
    class ChannelSubscription
      # Can be raised if a Subscription failed for any reason.
      class Failed < StandardError
      end

      attr_reader :channel_key, :params, :sequence, :timeout

      def self.redis
        @redis ||= Firehose::Server.redis.connection
      end

      def self.subscriber
        @subscriber ||= Server::Subscriber.new
      end

      def initialize(channel_key, sequence: 0, params: {}, timeout: nil)
        @redis        = self.class.redis
        @subscriber   = self.class.subscriber
        @sequence     = sequence
        @timeout      = timeout
        @channel_key  = channel_key
        @deferrable = EM::DefaultDeferrable.new
        @deferrable.errback {|e| EM.next_tick { raise e } unless [:timeout, :disconnect].include?(e) }
        on_subscribe(params)
      end

      def on_subscribe(params)
        message_filter.on_subscribe(params)
      end

      def on_unsubscribe
        message_filter.on_unsubscribe
      end

      def on_message(message)
        message_filter.process(message)
      end

      def next_messages
        list_key     = Server::Redis.key(channel_key, :list)
        sequence_key = Server::Redis.key(channel_key, :sequence)

        @redis.multi
          @redis.get(sequence_key).
            errback {|e| @deferrable.fail e }
          # Fetch entire list: http://stackoverflow.com/questions/10703019/redis-fetch-all-value-of-list-without-iteration-and-without-popping
          @redis.lrange(list_key, 0, -1).
            errback {|e| @deferrable.fail e }
        @redis.exec.callback do |(channel_sequence, message_list)|
          # Reverse the messages so they can be correctly procesed by the MessageBuffer class. There's
          # a patch in the message-buffer-redis branch that moves this concern into the Publisher LUA
          # script. We kept it out of this for now because it represents a deployment risk and `reverse!`
          # is a cheap operation in Ruby.
          message_list.reverse!
          buffer = MessageBuffer.new(message_list, channel_sequence, @sequence)
          if buffer.remaining_messages.empty?
            Firehose.logger.debug "No messages in buffer, subscribing. sequence: `#{channel_sequence}` consumer_sequence: #{@sequence}"
            # Either this resource has never been seen before or we are all caught up.
            # Subscribe and hope something gets published to this end-point.
            subscribe
          else # Either the client is under water or caught up to head.
            @deferrable.succeed process_messages buffer.remaining_messages
            @deferrable.callback { on_unsubscribe }
          end
        end.errback {|e| @deferrable.fail e }
        # TODO -ARRRG!!!! We can't listen to deferrables here. Need to expose those
        # on this class because this is a class var. In practice thats how we roll anyway.
        @deferrable
      end

      def unsubscribe
        @subscriber.unsubscribe self
      end

      def process_messages(messages)
        @deferrable.succeed messages.each { |m| on_message(m) }
      end

      private

      def message_filter
        @message_filter ||= begin
          if mf = Server.configuration.message_filter
            mf.new(self)
          else
            Firehose::Server::MessageFilter.new(self)
          end
        end
      end

      def subscribe
        @subscriber.subscribe self
        if @timeout
          timer = EventMachine::Timer.new(@timeout) do
            @deferrable.fail :timeout
            unsubscribe
          end
          # Cancel the timer if when the deferrable succeeds
          @deferrable.callback { timer.cancel }
        end
      end
    end
  end
end
