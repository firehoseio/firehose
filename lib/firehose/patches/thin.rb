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

require 'firehose/patches/swf_policy_request'
require 'thin'
# Ensure the class already exists so we are overwriting it.
Thin::Connection

class Thin::Connection
  include Firehose::Patches::SwfPolicyRequest
  alias_method :receive_data_without_swf_policy, :receive_data
  def receive_data(data)
    if handle_swf_policy_request(data)
      return false
    else
      receive_data_without_swf_policy(data)
    end
  end
end
