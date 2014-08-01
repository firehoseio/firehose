require 'spec_helper'
require 'rack/test'
require 'async_rack_test'

describe Firehose::Rack::BatchPublisher, :type => :request do
  include AsyncRackTest::Methods
  let(:app) { Firehose::Rack::BatchPublisher.new }
  let(:path) { "/test/path/#{Time.now.to_i}" }
  let(:deferrable) { EM::DefaultDeferrable.new }

  it "should publish each message with the given ttl" do
    body = {
      "/first/path" => {
        "messages" => [{"message" => "one"}, {"message" => "two"}],
        "ttl" => 90
      },
      "/second/path" => {
        "messages" => [{"msg" => "three"}, {"msg" => "four"}],
        "ttl" => 120
      }
    }
    body.each do |channel, data|
      data["messages"].each do |msg|
        Firehose::Server::Publisher.any_instance.should_receive(:publish)
          .with(channel, msg, :ttl => data["ttl"]).and_return(deferrable)
      end
    end

    deferrable.succeed # Need this or the HTTP request never returns.

    apost "/", body.to_json
  end

  context "all publishing is successful" do
    before { deferrable.succeed }

    it "should return 200" do
      Firehose::Server::Publisher.any_instance.stub(:publish).and_return(deferrable)

      apost "/", {
        "/first/path" => {
          "messages" => [{"message" => "one"}, {"message" => "two"}],
          "ttl" => 90
        },
        "/second/path" => {
          "messages" => [{"msg" => "three"}, {"msg" => "four"}],
          "ttl" => 120
        }
      }.to_json
      last_response.status.should == 200
    end
  end

  context "body is not valid JSON" do
    it "should return 400" do
      apost "/", "not json"
      last_response.status.should == 400
    end
  end
end

