module Firehose
  module Server
    # Handles processing message middleware in either a channel or a subscription.
    class MessageHandler
      attr_reader :channel, :deferrable, :consumer

      def initialize(channel: , consumer: )
        @consumer = consumer
        @deferrable = EM::DefaultDeferrable.new
        @channel = channel
        # Raise exceptions for timeouts an disconnects in EM
        deferrable.errback {|e| EM.next_tick { raise e } unless [:timeout, :disconnect].include?(e) }
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

      def process(messages)
        deferrable.succeed messages
      end
    end
  end
end
