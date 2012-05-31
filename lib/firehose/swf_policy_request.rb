module Firehose
  module SwfPolicyRequest

    # Borrowed from: https://github.com/igrigorik/em-websocket/blob/3e7f7d7760cc23b9d1d34fc1c17bab4423b5d11a/lib/em-websocket/connection.rb#L104
    def handle_swf_policy_request(data)
      if data =~ /\A<policy-file-request\s*\/>/
        Firehose.logger.debug "Received SWF Policy request: #{data.inspect}"
        send_data policy
        close_connection_after_writing
        true
      end
    end

    def policy
      <<-EOS
<?xml version="1.0"?>
<cross-domain-policy>
  <allow-access-from domain="*" to-ports="*"/>
</cross-domain-policy>'
      EOS
    end
  end
end
