require 'spec_helper'

describe Firehose::Subscriber do
  include EM::TestHelper

  let(:channel_key)     { '/bears/are/mean' }
  let(:subscriber)      { Firehose::Subscriber.new(EM::Hiredis.connect) }
  let(:message)         { 'Raaaarrrrrr!!!!' }
  let(:publisher)       { Firehose::Publisher.new }

  describe "#subscribe" do
    it "should add the deferrable to the subscriptions hash"
    it "should call succeed on the deferrable when a message is published"
    it "shouldn't call succeed on the deferrable when a 2nd message is published"
  end

  describe "#unsubscribe" do
    it "should remove the deferrable from the subscriptions hash"
    it "shouldn't call succeed on the deferrable when a message is published"
  end
end
