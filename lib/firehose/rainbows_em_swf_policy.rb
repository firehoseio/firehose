# This file file monkeypatches Rainbows! to return a proper SWF policy file.
# Enable this with something like this in your config/rainbows.rb file:
#
#     after_fork do |server, worker|
#       require 'firehose/rainbows_em_swf_policy'
#     end if ENV['RACK_ENV'] == 'development'
#
# You should only use this in development. It has not been well tested in a
# production environment.
#
# NOTE: This only works if you are using Rainbows! with EventMachine.
#
# Some helpful links:
# http://unicorn.bogomips.org/Unicorn/Configurator.html
# http://www.adobe.com/devnet/flashplayer/articles/socket_policy_files.html
# http://blog.vokle.com/index.php/2009/06/10/dealing-with-adobe-and-serving-socket-policy-servers-via-nginx-and-10-lines-of-code/

require 'rainbows'
# Ensure the class already exists so we are overwriting it.
Rainbows::EventMachine::Client

class Rainbows::EventMachine::Client
  include Firehose::SwfPolicyRequest
  alias_method :receive_data_without_swf_policy, :receive_data
  # Borrowed from: https://github.com/igrigorik/em-websocket/blob/3e7f7d7760cc23b9d1d34fc1c17bab4423b5d11a/lib/em-websocket/connection.rb#L104
  def receive_data(data)
    if handle_swf_policy_request(data)
      return false
    else
      receive_data_without_swf_policy(data)
    end
  end
end
