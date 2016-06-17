module Firehose
  module Server
    # Message object used internally by Firehose to represent a message that's published
    # to a client.
    class Message
      # We don't want Middleware, or anything, modifying the sequence of the message
      # once its set.
      attr_reader :sequence
      # We are OK with a middleware changing the message payload.
      attr_accessor :payload

      def initialize(payload, sequence)
        @payload = payload
        @sequence = sequence
      end

      def ==(other)
        payload == other.payload && sequence == other.sequence
      end
    end
  end
end
