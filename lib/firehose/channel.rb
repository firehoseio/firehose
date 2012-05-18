module Firehose
  class Channel
    attr_reader :channel, :redis, :subscriber

    def initialize(channel, redis=self.class.redis, subscriber=self.class.subscriber)
      @channel, @redis, @subscriber = channel, redis, subscriber
    end

    def next_message(last_sequence=nil)
      last_sequence = last_sequence.to_i

      deferrable = EM::DefaultDeferrable.new
      # TODO - Think this through a little harder... maybe some tests ol buddy!
      deferrable.errback {|e| raise e }
      
      list_key = key(channel, :list)
      sequence_key = key(channel, :sequence)

      redis.lindex(list_key, 0)
        .errback {|e| deferrable.fail e }
        .callback do |message|
          if message.nil?
            # This resource has never been seen before. Subscribe and hope something
            # gets published to this end-point
            subscriber.subscribe(channel, deferrable)
          else
            # We've published here before, so lets get the sequence key and do some stuff.
            redis.get(sequence_key)
              .errback {|e| deferrable.fail e }
              .callback do |sequence|
                sequence = sequence.to_i

                p [:seqs, sequence, last_sequence]

                if last_sequence.zero?
                  # If the sequence is 0, the client is hitting us for the first time, so
                  # give them the latest business!
                  redis.get(sequence_key)
                    .errback {|e| deferrable.fail e }
                    .callback do |sequence|
                      deferrable.succeed message, sequence.to_i
                    end
                else
                  # We've talked to the client before, so lets figure out how far behind they
                  # may be.
                  diff = sequence - last_sequence

                  if diff.zero?
                    # The client is caught up! Subscribe them for the new stuff.
                    subscriber.subscribe(channel, deferrable)
                  elsif diff < Firehose::Publisher::MAX_MESSAGES
                    # The client is kinda-sorta running behind, but has a chance to catch
                    # up. Catch them up FTW.
                    redis.lindex(list_key, diff)
                      .errback {|e| deferrable.fail e }
                      .callback do |message|
                        deferrable.succeed message, last_sequence + 1
                      end
                  else
                    # The client is hopelessly behind and underwater. Just reset 
                    # their whole world with the lastest message.
                    deferrable.succeed message, sequence
                  end
                end
              end
          end
        end

      deferrable
    end

    def self.redis
      @redis ||= EM::Hiredis.connect
    end

    def self.subscriber
      @subscriber ||= Firehose::Channel::Subscriber.new(EM::Hiredis.connect)
    end

    private
    def key(*segments)
      segments.unshift(:firehose).join(':')
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
          Firehose.logger.debug "Redis notifying #{deferrables.count} deferrable(s) at `#{channel_key}` with message `#{sequence}`"
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