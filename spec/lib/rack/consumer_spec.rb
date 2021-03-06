require 'spec_helper'
require 'rack/test'

describe Firehose::Rack::Consumer, :type => :request do
  include Rack::Test::Methods
  let(:app) { Firehose::Rack::Consumer.new }
  let(:path) { "/test/path/#{Time.now.to_i}" }

  it "has Content-Length on OPTIONS request"
  it "has Content-Length on GET request"

  context "configuration" do
    let(:app) { Firehose::Rack::Consumer }

    it "configures long polling timeout" do
      expect(app.new{ |a| a.http_long_poll.timeout = 300 }.http_long_poll.timeout).to eql(300)
    end
  end
end
