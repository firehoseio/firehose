require 'spec_helper'
require 'rack/test'
require 'async_rack_test'

describe Firehose::Rack::Ping, :type => :request do
  include AsyncRackTest::Methods
  let(:app) { Firehose::Rack::Ping.new dummy_redis }
  let(:path) { "/test/path/#{Time.now.to_i}" }
  let(:deferrable) { EM::DefaultDeferrable.new }
  let(:dummy_redis) { double 'redis', :set => deferrable, :get => deferrable, :expire => deferrable }

  context 'redis is available' do
    before { deferrable.succeed Firehose::Rack::Ping::PingCheck::TEST_VALUE }

    it "returns 200" do
      ahead path
      expect(last_response.status).to eql(200)
    end
  end

  context 'redis is not available' do
    before { deferrable.fail 'some error' }
    it "returns 500" do
      ahead path
      expect(last_response.status).to eql(500)
    end
  end
end
