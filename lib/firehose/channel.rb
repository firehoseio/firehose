module Firehose
  class Channel
    attr_reader :channel, :redis, :subscriber, :list_key, :sequence_key

    def self.redis
      @redis ||= EM::Hiredis.connect
    end

    def self.subscriber
      @subscriber ||= Firehose::Channel::Subscriber.new(EM::Hiredis.connect)
    end


    def initialize(channel, redis=self.class.redis, subscriber=self.class.subscriber)
      @channel, @redis, @subscriber = channel, redis, subscriber

      @list_key, @sequence_key = key(channel, :list), key(channel, :sequence)
    end

    def next_message(last_sequence=nil, options={})
      last_sequence = last_sequence.to_i

      deferrable = EM::DefaultDeferrable.new
      # TODO - Think this through a little harder... maybe some tests ol buddy!
      deferrable.errback {|e| raise e unless e == :timeout}

      redis.get(sequence_key)
        .errback {|e| deferrable.fail e }
        .callback do |sequence|
          sequence = sequence.to_i

          if sequence.nil? || (diff = sequence - last_sequence).zero?
            # Either this resource has never been seen before or we are all caught up.
            # Subscribe and hope something gets published to this end-point.
            subscribe(deferrable, options[:timeout])
          elsif diff < Firehose::Publisher::MAX_MESSAGES
            # The client is kinda-sorta running behind, but has a chance to catch
            # up. Catch them up FTW.
            succeed deferrable, diff, last_sequence + 1
          else
            # The client is hopelessly behind and underwater. Just reset
            # their whole world with the lastest message.
            succeed deferrable, 0, sequence
          end
        end

      deferrable
    end

    private
    def key(*segments)
      segments.unshift(:firehose).join(':')
    end

    def subscribe(deferrable, timeout=nil)
      subscriber.subscribe(channel, deferrable)
      if timeout
        timer = EventMachine::Timer.new(timeout) do
          deferrable.fail :timeout
        end
        # Cancel the timer if when the deferrable succeeds
        deferrable.callback { timer.cancel }
      end
    end

    def succeed(deferrable, index, sequence)
      redis.lindex(list_key, index)
        .errback {|e| deferrable.fail e }
        .callback do |message|
          deferrable.succeed message, sequence
        end
    end
  end

  # Setups a connetion to Redis to listen for new resources...
  class Channel::Subscriber
    attr_reader :redis

    def initialize(redis)
      @redis = redis

      redis.subscribe('firehose:channel_updates')
        .errback{|e| raise e }
        .callback { Firehose.logger.debug "Redis subscribed to `firehose:channel_updates`" }
      redis.on(:message) do |_, payload|
        channel_key, sequence, message = Firehose::Publisher.from_payload(payload)

        if deferrables = subscriptions.delete(channel_key)
          Firehose.logger.debug "Redis notifying #{deferrables.count} deferrable(s) at `#{channel_key}` with sequence `#{sequence}` and message `#{message}`"
          deferrables.each do |deferrable|
            deferrable.succeed message, sequence.to_i
          end
        end
      end
    end

    def subscribe(channel_key, deferrable)
      subscriptions[channel_key].push deferrable
    end

    private
    def subscriptions
      @subscriptions ||= Hash.new{|h,k| h[k] = []}
    end

    def key(*segments)
      segments.unshift(:firehose).join(':')
    end
  end
end
