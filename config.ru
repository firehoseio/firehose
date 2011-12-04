require 'push'

use Rack::CommonLogger
use Rack::ShowExceptions
use Rack::Reloader

Push.config do |c|
  c.backend = :amqp
end

map '/favicon.ico' do
  run Proc.new{ [200, {}, []]}
end

map '/' do
  run Push::Transport::HttpLongPoll.new {|c|
    c.timeout = 10
  }
end