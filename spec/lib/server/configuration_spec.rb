require 'spec_helper'

class CustomFilter < Firehose::Server::MessageFilter
end

describe Firehose::Server::Configuration do
  include EM::TestHelper

  DEFAULT_REDIS_URL = URI(Firehose::Server::Redis::DEFAULT_URL)

  describe "configuring Firehose" do
    it "sets the default values" do
      config = Firehose::Server.configuration
      expect(config.message_filter).to eql(Firehose::Server::MessageFilter)
      expect(config.redis.url).to eql(DEFAULT_REDIS_URL)
      expect(config.deprecated_channels.to_a).to eql([])
    end

    it "overrides values when given a configuration block" do
      redis_url = URI("redis://foo@bar")

      config = Firehose::Server.configuration do |conf|
        conf.message_filter = CustomFilter
      end

      expect(config.message_filter).to eql(CustomFilter)

      config = Firehose::Server.configuration do |conf|
        conf.redis.url = redis_url
      end

      expect(config.redis.url).to eql(redis_url)

      config = Firehose::Server.configuration do |conf|
        conf.redis.url = DEFAULT_REDIS_URL
      end

      expect(config.redis.url).to eql(DEFAULT_REDIS_URL)
      expect(config.deprecated_channels.to_a).to eql([])

      config = Firehose::Server.configuration do |conf|
        conf.deprecated_channels = ["/foo", "/foo/bar"]
        conf.deprecated_channel do |channel|
          channel =~ /^\/foo\/(\d+)$/
        end
      end

      expect(config.deprecated_channels.to_a).to eql(["/foo", "/foo/bar"])
      expect(config.channel_deprecated?("/foo")).to be true
      expect(config.channel_deprecated?("/foo/bar")).to be true
      expect(config.channel_deprecated?("/foobar")).to be false
      expect(config.channel_deprecated?("/foo/123")).to be true
      expect(config.channel_deprecated?("/foo/123abc")).to be false
      expect(config.channel_deprecated?("/foo/123/456")).to be false
      expect(config.channel_deprecated?("/foo/123/bar")).to be false
    end
  end
end
