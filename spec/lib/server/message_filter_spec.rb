require 'spec_helper'

class MinValFilter < Firehose::Server::MessageFilter
  JSONError = JSON.generate(error: "RandomFilter failed")

  def initialize(channel, min)
    super(channel)
    @min = min
  end

  def on_subscribe(params)
    unless params["valid"]
      raise Firehose::Server::ChannelSubscription::Failed, "Invalid params"
    end
  end

  def process(message)
    if message.json_payload["val"] < @min
      message.payload = JSONError
    end
  end
end

describe Firehose::Server::MessageFilter do
  include EM::TestHelper

  let(:mf)            { MinValFilter.new("/foo", 0.5) }
  let(:message_ok)    { Firehose::Server::Message.new(json_ok, 0) }
  let(:message_fail)  { Firehose::Server::Message.new(json_fail, 0) }
  let(:json_ok)       { JSON.generate(val: 0.6) }
  let(:json_fail)     { JSON.generate(val: 0.4) }
  let(:json_error)    { MinValFilter::JSONError }

  describe "#on_subscribe" do
    it "raises an exception if params invalid" do
      expect {
        mf.on_subscribe "valid" => false
      }.to raise_error(Firehose::Server::ChannelSubscription::Failed)
    end

    it "does not raise an exception if params valid" do
      expect {
        mf.on_subscribe "valid" => true
      }.to_not raise_error
    end
  end

  describe "#process" do
    it "doesn't change the message if the min val is reached" do
      msg = message_ok
      mf.process(msg)
      expect(msg.payload).to eql(json_ok)
    end

    it "returns an error message if the min val is not reached" do
      msg = message_fail
      mf.process(msg)
      expect(msg.payload).to_not eql(json_fail)
      expect(msg.payload).to eql(json_error)
    end
  end
end
