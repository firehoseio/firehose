module Firehose
  module Server
    # Handles processing message middleware in either a channel or a subscription.
    class MessageHandler
      attr_reader :channel, :deferrable

      def initialize(channel: )
        @deferrable = EM::DefaultDeferrable.new
        @channel = channel
        # Raise exceptions for timeouts an disconnects in EM
        deferrable.errback {|e| EM.next_tick { raise e } unless [:timeout, :disconnect].include?(e) }
      end

      def timeout(timeout, &block)
        timer = EventMachine::Timer.new(timeout) do
          deferrable.fail :timeout
          block.call self
        end
        # Cancel the timer if when the deferrable succeeds
        deferrable.callback { timer.cancel }
      end

      def process(messages)
        processed_messages = Array(messages).map do |message|
          message
        end
        # processed_messages = Array(messages).map do |message|
        #   p(message)
        #   message.payload = Middleware.new(
        #     message: message.payload,
        #     subscriber: channel.subscriber,
        #     channel: channel
        #   ).process
        #   messages
        # end

        deferrable.succeed processed_messages
      end
    end
  end
end
