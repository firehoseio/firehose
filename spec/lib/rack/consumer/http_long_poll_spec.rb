require 'spec_helper'
require 'rack/test'
require 'async_rack_test'

describe Firehose::Rack::Consumer::HttpLongPoll do
  include AsyncRackTest::Methods
  let(:app) { Firehose::Rack::Consumer::HttpLongPoll.new }

  context "transport" do
    # Transport for Firehose::Rack::App class is tested via the spec/integrations suite.
  end
  context "configuration" do
    it "has #timeout" do
      expect(Firehose::Rack::Consumer::HttpLongPoll.new(200).timeout).to eql(200)
    end
  end

  context "POST request" do
    before do
      post "/blah"
    end
    it "returns 405 for POST" do
      expect(last_response.status).to eql(405)
    end

    it "specifies GET in the Allow header" do
      expect(last_response.headers["Allow"]).to eql("GET")
    end
  end
end
