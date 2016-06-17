require 'spec_helper'

describe Firehose::Server::Redis do
  describe ".key" do
    subject { Firehose::Server::Redis.key("list", "channel", ["fizz", "buzz"]) }
    it "has root `firehose` key" do
      expect(subject).to start_with("firehose:")
    end
    it "flattens all arguments into key" do
      expect(subject).to eql("firehose:list:channel:fizz:buzz")
    end
  end
end
