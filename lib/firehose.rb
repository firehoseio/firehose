ENV['RACK_ENV'] ||= 'development' # TODO - Lets not rock out envs like its 1999.

require 'firehose/version'
require 'firehose/logging'

# TODO - Figure if we need to have an if/else for Rails::Engine loading and Firehose::Assets::Sprockets.auto_detect
require 'firehose/rails' if defined?(::Rails::Engine)

module Firehose
  autoload :Default,      'firehose/default'
  autoload :Producer,     'firehose/producer' # TODO Move this into the Firehose::Client namespace.
  autoload :Assets,       'firehose/assets'
  autoload :Rack,         'firehose/rack'
  autoload :CLI,          'firehose/cli'
  autoload :Client,       'firehose/client'
  autoload :Server,       'firehose/server'
  autoload :SwfPolicyRequest, 'firehose/swf_policy_request'
end

# Detect if Sprockets is loaded. If it is, lets configure Firehose to use it!
Firehose::Assets::Sprockets.auto_detect