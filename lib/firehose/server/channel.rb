module Firehose
  module Server
    # Connects to a specific channel on Redis and listens for messages to notify subscribers.
    class Channel
      attr_reader :channel_key

      def self.redis
        @redis ||= Firehose::Server.redis.connection
      end

      def self.subscriber
        @subscriber ||= Server::Subscriber.new
      end

      def initialize(channel_key, params: {}, redis: self.class.redis, subscriber: self.class.subscriber)
        @redis        = redis
        @subscriber   = subscriber
        @channel_key  = channel_key
        on_subscribe(params)
      end

      def on_subscribe(params)
      end

      def on_unsubscribe
      end

      def on_message(message)
      end

      def next_messages(consumer_sequence=nil, timeout: nil)
        list_key     = Server::Redis.key(channel_key, :list)
        sequence_key = Server::Redis.key(channel_key, :sequence)

        deferrable = EM::DefaultDeferrable.new
        deferrable.errback {|e| EM.next_tick { raise e } unless [:timeout, :disconnect].include?(e) }

        @redis.multi
          @redis.get(sequence_key).
            errback {|e| deferrable.fail e }
          # Fetch entire list: http://stackoverflow.com/questions/10703019/redis-fetch-all-value-of-list-without-iteration-and-without-popping
          @redis.lrange(list_key, 0, -1).
            errback {|e| deferrable.fail e }
        @redis.exec.callback do |(channel_sequence, message_list)|
          # Reverse the messages so they can be correctly procesed by the MessageBuffer class. There's
          # a patch in the message-buffer-redis branch that moves this concern into the Publisher LUA
          # script. We kept it out of this for now because it represents a deployment risk and `reverse!`
          # is a cheap operation in Ruby.
          message_list.reverse!
          buffer = MessageBuffer.new(message_list, channel_sequence, consumer_sequence)
          if buffer.remaining_messages.empty?
            Firehose.logger.debug "No messages in buffer, subscribing. sequence: `#{channel_sequence}` consumer_sequence: #{consumer_sequence}"
            # Either this resource has never been seen before or we are all caught up.
            # Subscribe and hope something gets published to this end-point.
            subscribe(deferrable, timeout)
          else # Either the client is under water or caught up to head.
            deferrable.succeed process_messages buffer.remaining_messages
            deferrable.callback { on_unsubscribe }
          end
        end.errback {|e| deferrable.fail e }

        deferrable
      end

      def unsubscribe(deferrable)
        @subscriber.unsubscribe channel_key, deferrable
      end

      private
      def process_messages(messages)
        messages.each { |m| on_message(m) }
      end
      def subscribe(deferrable, timeout=nil)
        @subscriber.subscribe(channel_key, deferrable)
        if timeout
          timer = EventMachine::Timer.new(timeout) do
            deferrable.fail :timeout
            unsubscribe deferrable
          end
          # Cancel the timer if when the deferrable succeeds
          deferrable.callback { timer.cancel }
        end
      end
    end
  end
end
