require 'spec_helper'

describe Firehose::Server::Message do
  subject { Firehose::Server::Message.new("hi there", 12) }
  # These tests might seem stupid and basic, but its making sure that
  # middleware can't modify the sequence of a message. If it could then
  # we'd open up Firehose middleware to breaking lots of stuff.
  context "mutability" do
    describe "#payload" do
      it "can be changed" do
        subject.payload = "I love pizza"
        expect(subject.payload).to eql("I love pizza")
      end
    end
    describe "#sequence" do
      it "can't be changed" do
        expect{ subject.sequence = 2 }.to raise_exception(NoMethodError)
        expect(subject.sequence).to eql(12)
      end
    end
  end
end
