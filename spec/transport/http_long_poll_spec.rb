require 'spec_helper'
require 'rack/test'

describe Push::Transport::HttpLongPoll do
  include Rack::Test::Methods

  def app
    Push::Transport::HttpLongPoll.new(Push::Backend::Test.new)
  end

  # This is a helper for testing GET requests on async webservers like 
  # Thin and Rainbow that support async.close and async.callback.
  def aget(uri, params={}, env={}, &block)
    env = {'async.callback' => nil, 'async.close' => nil}.merge(env)
    get "/", {}, {'async.callback' => nil}
  end

  it "should raise exception of the server does not support streaming" do
    lambda{
      get "/"
    }.should raise_exception(Push::Transport::HttpLongPoll::Stream::NotSupported)
  end
end