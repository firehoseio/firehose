module Firehose
  module Server
    # Encapsulates a sequence of messages from the server along with their
    # last_sequence_ids calculate by offset.
    class MessageOffset
      include Enumerable
      extend Forwardable
      def_delegator :@messages, :size

      Message = Struct.new(:payload, :sequence)

      def initialize(message_list, sequence, last_sequence = nil)
        @sequence = sequence.to_i
        @last_sequence = last_sequence.to_i
        @message_list = message_list
      end

      # Calculates the last_message_sequence per message.
      def messages
        @message_list.last(diff).map.with_index do |payload, index|
          # TODO: Where should we log this?
          # Firehose.logger.debug "Sending latest message `#{message.payload}` and sequence `#{message.sequence}` to client directly."
          Message.new(payload, @sequence + index)
        end
      end

      def each
        messages.each do |m|
          yield m
        end
      end

      def subscribable?
        diff >= 0
      end

      private
      def diff
        @sequence - @last_sequence
      end
    end
  end
end
