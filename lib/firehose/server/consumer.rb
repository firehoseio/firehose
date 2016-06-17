module Firehose
  module Server
    # Represents the current state of a consumer to the Firehose
    # server and middleware.
    class Consumer
      attr_accessor :metadata, :sequence, :timeout

      def initialize(sequence: 0, metadata: {})
        @metadata = metadata
        @sequence = sequence
      end

      def channel(channel_key)
        Server::Channel.new channel_key: channel_key, consumer: self
      end
    end
  end
end
