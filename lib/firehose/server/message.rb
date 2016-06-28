module Firehose
  module Server
    class Message < Struct.new(:payload, :sequence)
      def json_payload
        JSON.parse payload
      end
    end
  end
end
