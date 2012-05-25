require 'firehose'
require 'rack'

use Rack::Reloader

run Firehose::Rack::App.new
