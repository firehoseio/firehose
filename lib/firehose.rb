ENV['RACK_ENV'] ||= 'development'

require 'firehose/version'
require 'firehose/logging'
require 'em-hiredis'

require 'firehose/rails' if defined?(::Rails::Engine)

module Firehose
  autoload :Subscriber,   'firehose/subscriber'
  autoload :Publisher,    'firehose/publisher'
  autoload :Producer,     'firehose/producer'
  autoload :Default,      'firehose/default'
  autoload :Rack,         'firehose/rack'
  autoload :CLI,          'firehose/cli'
  autoload :Server,       'firehose/server'
  autoload :Channel,      'firehose/channel'
  autoload :SwfPolicyRequest, 'firehose/swf_policy_request'
end
