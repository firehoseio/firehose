require 'spec_helper'
require 'rack/test'

describe Push::Transport::HttpLongPoll do
  include Rack::Test::Methods

  def app
    Push::Transport::HttpLongPoll.new
  end

  it "should be configurable" do
    get "/"
  end
end