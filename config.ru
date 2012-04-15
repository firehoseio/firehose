require 'push'
require 'rack'

use Rack::Reloader

run Push::Rack::App.new