module Firehose
  module Server
    # Encapsulates a sequence of messages from the server along with their
    # consumer_sequences calculate by offset.
    class MessageBuffer
      # Number of messages that Redis buffers for the client if its
      # connection drops, then reconnects.
      DEFAULT_SIZE = 100

      def initialize(message_list, channel_sequence, consumer_sequence = nil)
        @message_list = message_list
        @channel_sequence = channel_sequence.to_i
        @consumer_sequence = consumer_sequence.to_i
      end

      def remaining_messages
        messages.last(remaining_message_count)
      end

      private

      def remaining_message_count
        # Special case to always get the latest message.
        return 1 unless @consumer_sequence > 0

        count = @channel_sequence - @consumer_sequence

        if count < 0
          # UNEXPECTED: Somehow the sequence is ahead of the channel.
          #             It is likely a bug in the consumer, but we'll assume
          #             the consumer has all the messages.
          0
        elsif count > @message_list.size
          # Consumer is under water since the last request. Just send the most recent message.
          1
        else
          count
        end
      end

      # Calculates the last_message_sequence per message.
      # [a b c e f]
      def messages
        @messages ||= @message_list.map.with_index do |payload, index|
          Message.new(payload, starting_channel_sequence + index)
        end
      end

      # Channel sequence is   10
      # Buffer size of        5
      # Start of sequence in buffer ... which would be 6
      def starting_channel_sequence
        @channel_sequence - @message_list.size + 1
      end
    end
  end
end
