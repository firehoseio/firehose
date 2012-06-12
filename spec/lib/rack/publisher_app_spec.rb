require 'spec_helper'
require 'rack/test'
require 'async_rack_test'

describe Firehose::Rack::PublisherApp, :type => :request do
  include AsyncRackTest::Methods
  let(:app) { Firehose::Rack::PublisherApp.new }
  let(:path) { "/test/path/#{Time.now.to_i}" }
  let(:deferrable) { EM::DefaultDeferrable.new }

  context 'publishing is successful' do
    before { deferrable.succeed }

    it "should return 202" do
      app.stub(:publisher => double('publisher', :publish => deferrable))
      aput path, :body => "some nice little message"
      last_response.status.should == 202
    end

    it "should have Content-Length of zero" do
      app.stub(:publisher => double('publisher', :publish => deferrable))
      aput path, :body => "some nice little message"
      last_response.headers['Content-Length'].should == '0'
    end
  end
end
