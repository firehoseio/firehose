require 'spec_helper'

describe Firehose::Server::MessageBuffer do
  it "has 100 DEFAULT_SIZE" do
    expect(Firehose::Server::MessageBuffer::DEFAULT_SIZE).to eql(100)
  end
  subject { Firehose::Server::MessageBuffer.new(messages, channel_sequence, consumer_sequence) }
  context "no messages" do
    let(:messages) { [] }
    let(:channel_sequence) { 0 }
    shared_examples "empty channel" do
      it "has empty remaining" do
        expect(subject.remaining_messages).to be_empty
      end
      it "has empty consumed" do
        expect(subject.consumed_messages).to be_empty
      end
    end
    context "nil sequence" do
      let(:consumer_sequence) { nil }
      it_behaves_like "empty channel"
    end
    context "0 sequence" do
      let(:consumer_sequence) { 0 }
      it_behaves_like "empty channel"
    end
    context "negative sequence" do
      let(:consumer_sequence) { -1 }
      it_behaves_like "empty channel"
    end
    context "positive sequence" do
      let(:consumer_sequence) { 100 }
      it_behaves_like "empty channel"
    end
  end
  context "has messages (buffer size of 5, at channel sequence 5)" do
    let(:messages) { %w[a b c d e] }
    let(:channel_sequence) { 5 }
    shared_examples "sequenced messages" do
      it "returns all messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(messages)
      end
      it "has correct sequences" do
        expect(subject.remaining_messages.map(&:sequence)).to eql((1..5).to_a)
      end
    end
    shared_examples "no messages consumed" do
      it "consumed is empty" do
        expect(subject.consumed_messages).to be_empty
      end
      it "remaining messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(messages)
      end
      it "has 0 offset" do
        expect(subject.offset).to eql(0)
      end
    end
    shared_examples "all messages consumed" do
      it "consumed is empty" do
        expect(subject.consumed_messages.map(&:payload)).to eql(messages)
      end
      it "remaining messages" do
        expect(subject.remaining_messages).to be_empty
      end
      it "has 0 offset" do
        expect(subject.offset).to eql(5)
      end
    end
    context "nil sequence" do
      let(:consumer_sequence) { nil }
      it_behaves_like "sequenced messages"
      it_behaves_like "no messages consumed"
    end
    context "0 sequence" do
      let(:consumer_sequence) { 0 }
      it_behaves_like "sequenced messages"
      it_behaves_like "no messages consumed"
    end
    context "negative sequence" do
      let(:consumer_sequence) { -1 }
      it_behaves_like "sequenced messages"
      it_behaves_like "no messages consumed"
    end
    context "running behind" do
      let(:consumer_sequence) { 2 }
      it "consumed is empty" do
        expect(subject.consumed_messages.map(&:payload)).to eql(%w[a b])
      end
      it "remaining messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(%w[c d e])
      end
      it "has 3 offset" do
        expect(subject.offset).to eql(2)
      end
    end
    context "caught up" do
      let(:consumer_sequence) { 5 }
      it_behaves_like "all messages consumed"
    end
    context "ahead" do
      let(:consumer_sequence) { 10 }
      it_behaves_like "all messages consumed"
    end
  end
  context "has messages (buffer size of 5, at channel sequence 10)" do
    let(:messages) { %w[f g h i j] }
    let(:channel_sequence) { 10 }
    shared_examples "sequenced messages" do
      it "returns all messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(messages)
      end
      it "has correct sequences" do
        expect(subject.remaining_messages.map(&:sequence)).to eql((6..10).to_a)
      end
    end
    shared_examples "no messages consumed" do
      it "consumed is empty" do
        expect(subject.consumed_messages).to be_empty
      end
      it "remaining messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(messages)
      end
      it "has 0 offset" do
        expect(subject.offset).to eql(0)
      end
    end
    shared_examples "all messages consumed" do
      it "consumed is empty" do
        expect(subject.consumed_messages.map(&:payload)).to eql(messages)
      end
      it "remaining messages" do
        expect(subject.remaining_messages).to be_empty
      end
      it "has 0 offset" do
        expect(subject.offset).to eql(5)
      end
    end
    context "nil sequence" do
      let(:consumer_sequence) { nil }
      it_behaves_like "sequenced messages"
      it_behaves_like "no messages consumed"
    end
    context "0 sequence" do
      let(:consumer_sequence) { 0 }
      it_behaves_like "sequenced messages"
      it_behaves_like "no messages consumed"
    end
    context "negative sequence" do
      let(:consumer_sequence) { -1 }
      it_behaves_like "sequenced messages"
      it_behaves_like "no messages consumed"
    end
    context "underwater" do
      let(:consumer_sequence) { 1 }
      it_behaves_like "sequenced messages"
      it_behaves_like "no messages consumed"
    end
    context "running behind" do
      let(:consumer_sequence) { 8 }
      it "consumed is empty" do
        expect(subject.consumed_messages.map(&:payload)).to eql(%w[f g h])
      end
      it "remaining messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(%w[i j])
      end
      it "has 0 offset" do
        expect(subject.offset).to eql(3)
      end
    end
    context "caught up" do
      let(:consumer_sequence) { 10 }
      it_behaves_like "all messages consumed"
    end
    context "ahead" do
      let(:consumer_sequence) { 15 }
      it_behaves_like "all messages consumed"
    end
  end
end
