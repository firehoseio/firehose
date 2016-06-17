module Firehose
  module Server
    # Connects to a specific channel on Redis and listens for messages to notify subscribers.
    class Channel
      attr_reader :redis, :subscriber, :consumer, :name, :deferrable

      def self.redis
        @redis ||= Server.redis.connection
      end

      def self.subscriber
        @subscriber ||= Server::Subscriber.new(Server.redis.connection)
      end

      def initialize(name: , consumer: )
        @redis        = self.class.redis
        @subscriber   = self.class.subscriber
        @consumer     = consumer
        @name         = name
        @list_key     = Server::Redis.key(name, :list)
        @sequence_key = Server::Redis.key(name, :sequence)
        @deferrable   = EM::DefaultDeferrable.new
        @deferrable.errback {|e| EM.next_tick { raise e } unless [:timeout, :disconnect].include?(e) }
      end

      def next_messages
        redis.multi
          redis.get(@sequence_key).
            errback {|e| deferrable.fail e }
          # Fetch entire list: http://stackoverflow.com/questions/10703019/redis-fetch-all-value-of-list-without-iteration-and-without-popping
          redis.lrange(@list_key, 0, -1).
            errback {|e| deferrable.fail e }
        redis.exec.callback do |(channel_sequence, message_list)|
          # Reverse the messages so they can be correctly procesed by the MessageBuffer class. There's
          # a patch in the message-buffer-redis branch that moves this concern into the Publisher LUA
          # script. We kept it out of this for now because it represents a deployment risk and `reverse!`
          # is a cheap operation in Ruby.
          message_list.reverse!
          buffer = MessageBuffer.new(message_list, channel_sequence, consumer.sequence)
          if buffer.remaining_messages.empty?
            Firehose.logger.debug "No messages in buffer, subscribing. sequence: `#{channel_sequence}` consumer.sequence: #{consumer.sequence}"
            # Either this resource has never been seen before or we are all caught up.
            # Subscribe and hope something gets published to this end-point.
            subscribe
          else # Either the client is under water or caught up to head.
            send_messages buffer.remaining_messages
          end
        end.errback {|e| deferrable.fail e }

        @deferrable
      end

      def send_messages(messages)
        @deferrable.succeed messages
      end

      def unsubscribe
        subscriber.unsubscribe self
      end

      private
      def subscribe
        subscriber.subscribe self
        timeout { unsubscribe }
      end

      def timeout(&block)
        return if consumer.timeout.nil?

        timer = EventMachine::Timer.new(consumer.timeout) do
          deferrable.fail :timeout
          block.call self
        end
        # Cancel the timer if when the deferrable succeeds
        deferrable.callback { timer.cancel }
      end
    end
  end
end
