module Firehose
  module Server
    # Connects to a specific channel on Redis and listens for messages to notify subscribers.
    class Channel
      attr_reader :channel_key, :list_key, :sequence_key
      attr_reader :redis, :subscriber

      def self.redis
        @redis ||= Firehose::Server.redis.connection
      end

      def self.subscriber
        @subscriber ||= Server::Subscriber.new(Firehose::Server.redis.connection)
      end

      def initialize(channel_key, redis=self.class.redis, subscriber=self.class.subscriber)
        @redis        = redis
        @subscriber   = subscriber
        @channel_key  = channel_key
        @list_key     = Server::Redis.key(channel_key, :list)
        @sequence_key = Server::Redis.key(channel_key, :sequence)
      end

      def next_messages(consumer)
        handler = Firehose::Server::MessageHandler.new(channel: self, consumer: consumer)
        redis.multi
          redis.get(sequence_key).
            errback {|e| handler.deferrable.fail e }
          # Fetch entire list: http://stackoverflow.com/questions/10703019/redis-fetch-all-value-of-list-without-iteration-and-without-popping
          redis.lrange(list_key, 0, -1).
            errback {|e| handler.deferrable.fail e }
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
            subscribe(handler)
          else # Either the client is under water or caught up to head.
            handler.process buffer.remaining_messages
          end
        end.errback {|e| deferrable.fail e }

        handler.deferrable
      end

      def unsubscribe(handler)
        subscriber.unsubscribe channel_key, handler
      end

      private
      def subscribe(handler)
        subscriber.subscribe(channel_key, handler)
        handler.timeout { unsubscribe handler }
      end
    end
  end
end
