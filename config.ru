require 'push'

use Rack::CommonLogger
use Rack::ShowExceptions
use Rack::Reloader

map '/favicon.ico' do
  run Proc.new{ [204, {}, []] }
end

map '/' do
  run Push::Server.new
end