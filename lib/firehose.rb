ENV['RACK_ENV'] ||= 'development' # TODO - Lets not rock out envs like its 1999.

require 'uri'
require 'firehose/version'
require 'firehose/logging'

# TODO - Figure if we need to have an if/else for Rails::Engine loading and Firehose::Assets::Sprockets.auto_detect
require 'firehose/rails' if defined?(::Rails::Engine)

module Firehose
  autoload :Server,       'firehose/server'
  autoload :Client,       'firehose/client'
  autoload :Assets,       'firehose/assets'
  autoload :Rack,         'firehose/rack'
  autoload :CLI,          'firehose/cli'

  # Default URI for the Firehose server. Consider the port "well-known" and bindable from other apps.
  URI = URI.parse("//0.0.0.0:7474").freeze
end

# Detect if Sprockets is loaded. If it is, lets configure Firehose to use it!
Firehose::Assets::Sprockets.auto_detect