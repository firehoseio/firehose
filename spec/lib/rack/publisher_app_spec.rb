require 'spec_helper'
require 'rack/test'

describe Firehose::Rack::PublisherApp, :type => :request do
  include Rack::Test::Methods
  let(:app) { Firehose::Rack::PublisherApp.new }
  let(:path) { "/test/path/#{Time.now.to_i}" }

  it "should return 202" do
    app.stub(:publisher => double('publisher', :publish => nil))
    put path, :body => "some nice little message"
    last_response.status.should == 202
  end

  it "should have Content-Length of zero" do
    app.stub(:publisher => double('publisher', :publish => nil))
    put path, :body => "some nice little message"
    last_response.headers['Content-Length'].should == '0'
  end
end
