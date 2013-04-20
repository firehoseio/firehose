require 'spec_helper'

describe Firehose::Client::Producer::Http do
  let(:channel)       { "/channel-awesome" }
  let(:url)           { "#{Firehose::URI}#{channel}"}
  let(:publish_stub)  { stub_request(:put, url) }
  let(:message)       { "hey dude" }

  before(:all) do
    Firehose::Client::Producer::Http.adapter = :net_http
  end

  after(:all) do
    Firehose::Client::Producer::Http.adapter = nil
  end

  it "should publish message to channel" do
    publish_stub.to_return(:body => "", :status => 202)

    Firehose::Client::Producer::Http.new.publish(message).to(channel)
    WebMock.should have_requested(:put, url).with { |req| req.body == message }
  end

  context 'prefix is specified in URI' do
    let(:firehose_uri) {"#{Firehose::URI}/prefix"}
    let(:url) { "#{firehose_uri}#{channel}"}

    it "should publish message to channel" do
      publish_stub.to_return(:body => "", :status => 202)

      Firehose::Client::Producer::Http.new(firehose_uri).publish(message).to(channel)
      WebMock.should have_requested(:put, url).with { |req| req.body == message }
    end
  end

  it "should publish message to channel with expiry headers" do
    publish_stub.to_return(:body => "", :status => 202)
    ttl = 20

    Firehose::Client::Producer::Http.new.publish(message).to(channel, :ttl => ttl)
    WebMock.should have_requested(:put, url).with { |req| req.body == message and req.headers['Cache-Control'] == "max-age=#{ttl}" }
  end

  describe "connection error handling" do
    it "should raise PublishError if not 201" do
      publish_stub.to_return(:body => "", :status => 500)

      lambda{
        Firehose::Client::Producer::Http.new.publish(message).to(channel)
      }.should raise_exception(Firehose::Client::Producer::Http::PublishError)
    end

    it "should use .error_handler if not 201" do
      publish_stub.to_return(:body => "", :status => 500)

      producer = Firehose::Client::Producer::Http.new
      producer.on_error do |e|
        e.message.should =~ /could not publish.+to/i
      end
      producer.publish(message).to(channel)
    end

    it "should raise TimeoutError if timed out" do
      publish_stub.to_timeout

      lambda{
        Firehose::Client::Producer::Http.new.publish(message).to(channel)
      }.should raise_exception(Firehose::Client::Producer::Http::TimeoutError)
    end
  end
end
