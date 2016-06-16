require 'spec_helper'

describe Firehose::Server::Consumer do
  subject { Firehose::Server::Consumer.new }
  context "defaults" do
    it "#metadata == {}" do
      expect(subject.metadata).to eql({})
    end
    it "#sequence == 0" do
      expect(subject.sequence).to be_zero
    end
    it "#timeout == nil" do
      expect(subject.timeout).to be_nil
    end
  end
end
