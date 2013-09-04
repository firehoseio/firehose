require 'spec_helper'

describe Firehose::Rack::Consumer::HttpLongPoll do
  context "transport" do
    # Transport for Firehose::Rack::App class is tested via the spec/integrations suite.
  end
  context "configuration" do
    it "should have #timeout" do
      Firehose::Rack::Consumer::HttpLongPoll.new(200).timeout.should == 200
    end
  end
end