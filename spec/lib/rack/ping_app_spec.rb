require 'spec_helper'
require 'rack/test'
require 'async_rack_test'

describe Firehose::Rack::PingApp, :type => :request do
  include AsyncRackTest::Methods
  let(:app) { Firehose::Rack::PingApp.new dummy_redis }
  let(:path) { "/test/path/#{Time.now.to_i}" }
  let(:deferrable) { EM::DefaultDeferrable.new }
  let(:dummy_redis) { double 'redis', :set => deferrable, :get => deferrable, :expire => deferrable }

  context 'redis is available' do
    before { deferrable.succeed Firehose::Rack::PingApp::PingCheck::TEST_VALUE }

    it "should return 200" do
      ahead path
      last_response.status.should == 200
    end
  end

  context 'redis is not available' do
    before { deferrable.fail 'some error' }
    it "should return 500" do
      ahead path
      last_response.status.should == 500
    end
  end
end
