require 'spec_helper'

describe Firehose::Server::MessageOffset do
  subject { Firehose::Server::MessageOffset.new(messages, sequence, last_sequence) }
  let(:messages) { %w[f g h i j] }
  let(:sequence) { 10 }
  context "nil sequence" do
    let(:last_sequence) { nil }
    it { is_expected.to be_subscribable }
  end
  context "0 sequence" do
    let(:last_sequence) { 0 }
    it { is_expected.to be_subscribable }
  end
  context "negative sequence" do
    let(:last_sequence) { -1 }
    it { is_expected.to be_subscribable }
  end
  context "underwater" do
    let(:last_sequence) { 1 }
    it "returns 5 messages" do
      expect(subject.messages.map(&:payload)).to eql(messages)
    end
  end
  context "running behind" do
    let(:last_sequence) { 8 }
    it "expects last 2 messages" do
      expect(subject.messages.map(&:payload)).to eql(%w[i j])
    end
  end
  context "caught up" do
    let(:last_sequence) { 10 }
    it { is_expected.to be_subscribable }
  end
end
