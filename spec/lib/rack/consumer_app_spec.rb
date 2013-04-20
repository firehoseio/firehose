require 'spec_helper'
require 'rack/test'

describe Firehose::Rack::Consumer, :type => :request do
  include Rack::Test::Methods
  let(:app) { Firehose::Rack::Consumer.new }
  let(:path) { "/test/path/#{Time.now.to_i}" }

  it "should have Content-Length on OPTIONS request"
  it "should have Content-Length on GET request"
end
