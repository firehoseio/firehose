module Firehose
  class Channel
    attr_reader :channel_key, :redis, :subscriber, :list_key, :sequence_key

    def self.redis
      @redis ||= EM::Hiredis.connect
    end

    def self.subscriber
      @subscriber ||= Subscriber.new(EM::Hiredis.connect)
    end


    def initialize(channel_key, redis=self.class.redis, subscriber=self.class.subscriber)
      @channel_key, @redis, @subscriber = channel_key, redis, subscriber

      @list_key, @sequence_key = key(channel_key, :list), key(channel_key, :sequence)
    end

    def next_message(last_sequence=nil, options={})
      last_sequence = last_sequence.to_i

      deferrable = EM::DefaultDeferrable.new
      # TODO - Think this through a little harder... maybe some tests ol buddy!
      deferrable.errback {|e| raise e unless [:timeout, :disconnect].include?(e) }


      # TODO: Use HSET so we don't have to pull 100 messages back every time.
      redis.multi
        redis.get(sequence_key)
          .errback {|e| deferrable.fail e }
        redis.lrange(list_key, 0, Firehose::Publisher::MAX_MESSAGES)
          .errback {|e| deferrable.fail e }
      redis.exec.callback do |(sequence, message_list)|
        Firehose.logger.debug "exec returened: `#{sequence}` and `#{message_list.inspect}`"
        sequence = sequence.to_i

        if sequence.nil? || (diff = sequence - last_sequence).zero?
          Firehose.logger.debug "No message available yet, subscribing. sequence: `#{sequence}`"
          # Either this resource has never been seen before or we are all caught up.
          # Subscribe and hope something gets published to this end-point.
          subscribe(deferrable, options[:timeout])
        elsif diff < Firehose::Publisher::MAX_MESSAGES
          # The client is kinda-sorta running behind, but has a chance to catch
          # up. Catch them up FTW.
          message = message_list[diff-1]
          Firehose.logger.debug "Sending old message `#{message}` and sequence `#{sequence}` to client directly. Client is `#{diff}` behind, at `#{last_sequence}`."
          deferrable.succeed message, last_sequence + 1
        else
          # The client is hopelessly behind and underwater. Just reset
          # their whole world with the lastest message.
          message = message_list[0]
          Firehose.logger.debug "Sending latest message `#{message}` and sequence `#{sequence}` to client directly."
          deferrable.succeed message, sequence
        end
      end.errback {|e| deferrable.fail e }

      deferrable
    end

    def unsubscribe(deferrable)
      subscriber.unsubscribe channel_key, deferrable
    end

    private
    def key(*segments)
      segments.unshift(:firehose).join(':')
    end

    def subscribe(deferrable, timeout=nil)
      subscriber.subscribe(channel_key, deferrable)
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
