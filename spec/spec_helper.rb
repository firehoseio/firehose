require 'rubygems'
require 'bundler/setup'
require 'push'
require 'rspec'
require 'push/test'
require 'em-ventually'

# Keep our rspec output clean from the push logger
# Push.config.logger = Logger.new('/dev/null')

# Make our EM specs timeout if an assertion isn't made after 5 seconds
EM::Ventually.total_default = 5