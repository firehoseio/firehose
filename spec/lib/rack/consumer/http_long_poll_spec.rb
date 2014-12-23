require 'spec_helper'

describe Firehose::Rack::Consumer::HttpLongPoll do
  context "transport" do
    # Transport for Firehose::Rack::App class is tested via the spec/integrations suite.
  end
  context "configuration" do
    it "has #timeout" do
      expect(Firehose::Rack::Consumer::HttpLongPoll.new(200).timeout).to eql(200)
    end
  end
end