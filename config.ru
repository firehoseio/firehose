require 'push'

use Rack::CommonLogger
use Rack::ShowExceptions
use Rack::Reloader

run Push::Transport::HttpLongPoll.new do |c|
  c.timeout = 5
end