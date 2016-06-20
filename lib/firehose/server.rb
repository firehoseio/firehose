require 'faye/websocket'
require 'em-hiredis'

# Set the EM::Hiredis logger to be the same as the Firehose logger.
EM::Hiredis.logger = Firehose.logger

module Firehose
  # Firehose components that sit between the Rack HTTP software and the Redis server.
  # This mostly handles message sequencing and different HTTP channel names.
  module Server
    autoload :Configuration,    'firehose/server/configuration'
    autoload :MessageBuffer,    'firehose/server/message_buffer'
    autoload :MessageHandler,   'firehose/server/message_handler'
    autoload :Message,          'firehose/server/message'
    autoload :Subscriber,       'firehose/server/subscriber'
    autoload :Publisher,        'firehose/server/publisher'
    autoload :Channel,          'firehose/server/channel'
    autoload :Consumer,         'firehose/server/consumer'
    autoload :App,              'firehose/server/app'
    autoload :Redis,            'firehose/server/redis'

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.redis
      configuration.redis
    end
  end
end
