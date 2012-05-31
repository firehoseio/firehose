# This file file monkeypatches Thin to return a proper SWF policy file.
#
# You should only use this in development. It has not been well tested in a
# production environment.
#
# NOTE: This only works if you are using Thin with EventMachine.
#
# Some helpful links:
# http://www.adobe.com/devnet/flashplayer/articles/socket_policy_files.html
# http://blog.vokle.com/index.php/2009/06/10/dealing-with-adobe-and-serving-socket-policy-servers-via-nginx-and-10-lines-of-code/

require 'thin'
# Ensure the class already exists so we are overwriting it.
Thin::Connection

class Thin::Connection
  alias_method :receive_data_without_swf_policy, :receive_data
  # Borrowed from: https://github.com/igrigorik/em-websocket/blob/3e7f7d7760cc23b9d1d34fc1c17bab4423b5d11a/lib/em-websocket/connection.rb#L104
  def receive_data(data)
    if data =~ /\A<policy-file-request\s*\/>/
      policy = <<-EOS
<?xml version="1.0"?>
<cross-domain-policy>
  <allow-access-from domain="*" to-ports="*"/>
</cross-domain-policy>'
      EOS

      send_data policy
      close_connection_after_writing
      return false
    else
      receive_data_without_swf_policy(data)
    end
  end
end
