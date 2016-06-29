require 'spec_helper'
require 'rack/test'
require 'async_rack_test'

describe Firehose::Rack::Consumer::HttpLongPoll do
  include AsyncRackTest::Methods
  include EM::TestHelper

  let(:app) { Firehose::Rack::Consumer::HttpLongPoll.new }

  context "transport" do
    # Transport for Firehose::Rack::App class is tested via the spec/integrations suite.
  end

  context "configuration" do
    it "has #timeout" do
      expect(Firehose::Rack::Consumer::HttpLongPoll.new(200).timeout).to eql(200)
    end
  end

  describe "Single subscription" do
    context "GET request" do
      it "receives subscription params" do
        em do
          expect_any_instance_of(Firehose::Server::ChannelSubscription).to receive(:on_subscribe).with({"to" => "nuts"})
          get "/soup?to=nuts&last_message_sequence=1"
          EM.next_tick { em.stop }
        end
      end
    end
  end

  describe "Multiplexing subscription" do
    context "POST request" do
      it "parses implicit message sequence" do
        em do
          expect_any_instance_of(Firehose::Server::ChannelSubscription).to receive(:next_messages).with(1, timeout: 20).and_return(EM::DefaultDeferrable.new)
          post "/channels@firehose", JSON.generate("/soup" => 1)
          EM.next_tick { em.stop }
        end
      end
      it "parses explicit message sequence and params" do
        em do
          expect_any_instance_of(Firehose::Server::ChannelSubscription).to receive(:next_messages).with(1, timeout: 20).and_return(EM::DefaultDeferrable.new)
          expect_any_instance_of(Firehose::Server::ChannelSubscription).to receive(:on_subscribe).with({"soup" => "nuts"})
          post "/channels@firehose", JSON.generate({
              "/soup": {
                "last_message_sequence": 1,
                "soup": "nuts"
              }
            })
          EM.next_tick { em.stop }
        end
      end
    end
  end

  context "POST request" do
    before do
      post "/soup"
    end

    it "returns 405 for POST" do
      expect(last_response.status).to eql(405)
    end

    it "specifies GET in the Allow header" do
      expect(last_response.headers["Allow"]).to eql("GET")
    end
  end
end
