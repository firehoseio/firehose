module Firehose
  module Server
    # Encapsulates a sequence of messages from the server along with their
    # consumer_sequences calculate by offset.
    class MessageBuffer
      # Number of messages that Redis buffers for the client if its
      # connection drops, then reconnects.
      DEFAULT_SIZE = 100

      Message = Struct.new(:payload, :sequence)

      def initialize(message_list, channel_sequence, consumer_sequence = nil)
        @message_list = message_list
        @channel_sequence = channel_sequence.to_i
        @consumer_sequence = consumer_sequence.to_i
      end

      def consumed_messages
        messages.take(offset)
      end

      def remaining_messages
        messages.drop(offset)
      end

      def offset
        # Somehow the sequence is negative. Consumer needs all messages
        if @consumer_sequence < 0
          0
        # Somehow the sequence is ahead of the channel. Consumer has all the messages.
        elsif @consumer_sequence > @channel_sequence
          @message_list.size
        # Consumer is under water since the last request. Consumer needs messages.
        elsif @consumer_sequence < @channel_sequence - @message_list.size
          0
        # Consumer is behind a few messages and can catch up. Consumer only needs a few messages.
        else
          # Message list of 50
          # Consumer is at 950
          # Server is at 967
          # Consumer NEEDS 17 messages (or client can DROP 33 messages)
          @message_list.size - (@channel_sequence - @consumer_sequence)
        end
      end

      private
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
