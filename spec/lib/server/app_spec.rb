require 'spec_helper'

describe Firehose::Rack::App do
  context "transport" do
    # Transport for Firehose::Rack::App class is tested via the spec/integrations suite.
  end

  context "configuration" do
    let(:app) { Firehose::Rack::App }

    it "should configure long polling timeout" do
      app.new{ |a| a.consumer.http_long_poll.timeout = 300 }.consumer.http_long_poll.timeout.should == 300
    end
  end
end