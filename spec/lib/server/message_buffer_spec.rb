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

    shared_examples "latest message" do
      it "returns just the latest messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(["e"])
      end
      it "has the correct sequence" do
        expect(subject.remaining_messages.map(&:sequence)).to eql([5])
      end
    end

    context "nil sequence" do
      let(:consumer_sequence) { nil }
      it_behaves_like "latest message"
    end
    context "0 sequence" do
      let(:consumer_sequence) { 0 }
      it_behaves_like "latest message"
    end
    context "negative sequence" do
      let(:consumer_sequence) { -1 }
      it_behaves_like "latest message"
    end

    context "running behind" do
      let(:consumer_sequence) { 2 }
      it "has some remaining messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(%w[c d e])
      end
      it "has the correct sequences" do
        expect(subject.remaining_messages.map(&:sequence)).to eql((3..5).to_a)
      end
    end

    context "caught up" do
      let(:consumer_sequence) { 5 }
      it "has no remaining messages" do
        expect(subject.remaining_messages).to be_empty
      end
    end
    context "ahead" do
      let(:consumer_sequence) { 10 }
      it "has no remaining messages" do
        expect(subject.remaining_messages).to be_empty
      end
    end
  end
  context "has messages (buffer size of 5, at channel sequence 10)" do
    let(:messages) { %w[f g h i j] }
    let(:channel_sequence) { 10 }

    shared_examples "latest message" do
      it "returns just the latest messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(["j"])
      end
      it "has the correct sequence" do
        expect(subject.remaining_messages.map(&:sequence)).to eql([10])
      end
    end

    context "nil sequence" do
      let(:consumer_sequence) { nil }
      it_behaves_like "latest message"
    end
    context "0 sequence" do
      let(:consumer_sequence) { 0 }
      it_behaves_like "latest message"
    end
    context "negative sequence" do
      let(:consumer_sequence) { -1 }
      it_behaves_like "latest message"
    end
    context "underwater" do
      let(:consumer_sequence) { 2 }
      it_behaves_like "latest message"
    end

    context "almost underwater" do
      let(:consumer_sequence) { 5 }
      it "has all remaining messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(%w[f g h i j])
      end
      it "has the correct sequences" do
        expect(subject.remaining_messages.map(&:sequence)).to eql((6..10).to_a)
      end
    end

    context "running behind" do
      let(:consumer_sequence) { 7 }
      it "has some remaining messages" do
        expect(subject.remaining_messages.map(&:payload)).to eql(%w[h i j])
      end
      it "has the correct sequences" do
        expect(subject.remaining_messages.map(&:sequence)).to eql((8..10).to_a)
      end
    end

    context "caught up" do
      let(:consumer_sequence) { 10 }
      it "has no remaining messages" do
        expect(subject.remaining_messages).to be_empty
      end
    end
    context "ahead" do
      let(:consumer_sequence) { 15 }
      it "has no remaining messages" do
        expect(subject.remaining_messages).to be_empty
      end
    end
  end
end
