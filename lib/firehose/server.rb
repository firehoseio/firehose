require 'faye/websocket'
require 'em-hiredis'

# Set the EM::Hiredis logger to be the same as the Firehose logger.
EM::Hiredis.logger = Firehose.logger

module Firehose
  # Firehose components that sit between the Rack HTTP software and the Redis server.
  # This mostly handles message sequencing and different HTTP channel names.
  module Server
    autoload :Configuration,    'firehose/server/configuration'
    autoload :Message,          'firehose/server/message'
    autoload :MessageFilter,    'firehose/server/message_filter'
    autoload :MessageBuffer,    'firehose/server/message_buffer'
    autoload :Subscriber,       'firehose/server/subscriber'
    autoload :Publisher,        'firehose/server/publisher'
    autoload :Channel,          'firehose/server/channel'
    autoload :App,              'firehose/server/app'
    autoload :Redis,            'firehose/server/redis'

    def self.configuration(&block)
      @configuration ||= Configuration.new
      if block
        @configuration.instance_eval(&block)
      end
      @configuration
    end

    def self.redis
      configuration.redis
    end
  end
end
