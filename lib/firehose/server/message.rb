module Firehose
  module Server
    Message = Struct.new(:payload, :sequence) do
      def json_payload
        JSON.parse payload
      end
    end
  end
end
