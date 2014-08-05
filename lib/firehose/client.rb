require 'em-http'
require 'faye/websocket'

module Firehose
  # Ruby clients that connect to Firehose to either publish or consume messages.
  module Client
    autoload :Consumer, 'firehose/client/consumer'
    autoload :Producer, 'firehose/client/producer'
  end
end
