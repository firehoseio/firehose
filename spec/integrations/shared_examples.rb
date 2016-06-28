require 'spec_helper'
require 'integrations/integration_test_helper'
require 'json'

shared_examples_for 'Firehose::Rack::App' do
  include EM::TestHelper
  include IntegrationTestHelper

  before(:all) do
    Firehose::Client::Producer::Http.adapter = :em_http
    start_server
  end

  after(:all) do
    Firehose::Client::Producer::Http.adapter = nil
    stop_server
  end

  before(:each) { WebMock.disable! }
  after(:each)  { WebMock.enable! }

  let(:app)       { Firehose::Rack::App.new }
  let(:messages)  { (1..200).map{|n| "msg-#{n}" } }
  let(:channel)   { "/firehose/integration/#{Time.now.to_i}" }
  let(:http_url)  { "http://#{uri.host}:#{uri.port}#{channel}" }
  let(:http_multi_url) { "http://#{uri.host}:#{uri.port}/channels@firehose" }
  let(:ws_url)    { "ws://#{uri.host}:#{uri.port}#{channel}" }
  let(:multiplex_channels) { ["/foo/bar", "/bar/baz", "/baz/quux"] }
  let(:subscription_query) { multiplex_channels.map{|c| "#{c}!0"}.join(",") }

  it "supports pub-sub http and websockets" do
    # Setup variables that we'll use after we turn off EM to validate our
    # test assertions.
    outgoing, received = messages.dup, Hash.new{|h,k| h[k] = []}

    # Our WS and Http clients call this when they have received their messages to determine
    # when to turn off EM and make the test assertion at the very bottom.
    succeed = Proc.new do
      # TODO: For some weird reason the `add_timer` call causes up to 20 seconds of delay after
      #       the test finishes running. However, without it the test will randomly fail with a
      #       "Redis disconnected" error.
      em.add_timer(1) { em.stop } if received.values.all?{|arr| arr.size == messages.size }
    end

    # Setup a publisher
    publish = Proc.new do
      Firehose::Client::Producer::Http.new.publish(outgoing.shift).to(channel, buffer_size: rand(100)) do
        # The random timer ensures that sometimes the clients will be behind
        # and sometimes they will be caught up.
        EM::add_timer(rand*0.005) { publish.call } unless outgoing.empty?
      end
    end

    # Lets have an HTTP Long poll client
    http_long_poll = Proc.new do |cid, last_sequence|
      http = EM::HttpRequest.new(http_url).get(:query => {'last_message_sequence' => last_sequence})
      http.errback { em.stop }
      http.callback do
        frame = JSON.parse(http.response, :symbolize_names => true)
        received[cid] << frame[:message]
        if received[cid].size < messages.size
          # Add some jitter so the clients aren't syncronized
          EM::add_timer(rand*0.001) { http_long_poll.call cid, frame[:last_sequence] }
        else
          succeed.call cid
        end
      end
    end

    # And test a web socket client too, at the same time.
    websocket = Proc.new do |cid|
      ws = Faye::WebSocket::Client.new(ws_url)

      ws.onopen = lambda do |event|
        ws.send('{"last_message_sequence":0}')
      end

      ws.onmessage = lambda do |event|
        frame = JSON.parse(event.data, :symbolize_names => true)
        received[cid] << frame[:message]
        succeed.call cid unless received[cid].size < messages.size
      end

      ws.onclose = lambda do |event|
        ws = nil
      end

      ws.onerror = lambda do |event|
        raise 'ws failed' + "\n" + event.inspect
      end
    end

    # Great, we have all the pieces in order, lets run this thing in the reactor.
    em 180 do
      # Start the clients.
      websocket.call(1)
      websocket.call(2)
      http_long_poll.call(3)
      http_long_poll.call(4)

      # Wait a sec to let our clients set up.
      em.add_timer(1){ publish.call }
    end

    # When EM stops, these assertions will be made.
    expect(received.size).to eql(4)
    received.each_value do |arr|
      expect(arr.size).to eql(messages.size)
      expect(arr.sort).to eql(messages.sort)
    end
  end

  it "supports channel multiplexing for http_long_poll and websockets" do
    # Setup variables that we'll use after we turn off EM to validate our
    # test assertions.
    outgoing, received = messages.dup, Hash.new{|h,k| h[k] = []}

    # Our WS and Http clients call this when they have received their messages to determine
    # when to turn off EM and make the test assertion at the very bottom.
    succeed = Proc.new do
      # TODO: For some weird reason the `add_timer` call causes up to 20 seconds of delay after
      #       the test finishes running. However, without it the test will randomly fail with a
      #       "Redis disconnected" error.
      em.add_timer(1) { em.stop } if received.values.all?{|arr| arr.size == messages.size }
    end

    # Lets have an HTTP Long poll client using channel multiplexing
    multiplexed_http_long_poll = Proc.new do |cid, last_sequence|
      http = EM::HttpRequest.new(http_multi_url).get(:query => {'subscribe' => subscription_query})

      http.errback { em.stop }
      http.callback do
        frame = JSON.parse(http.response, :symbolize_names => true)
        received[cid] << frame[:message]
        if received[cid].size < messages.size
          # Add some jitter so the clients aren't syncronized
          EM::add_timer(rand*0.001) { multiplexed_http_long_poll.call cid, frame[:last_sequence] }
        else
          succeed.call cid
        end
      end
    end

    # Test multiplexed web socket client
    outgoing = messages.dup
    publish_multi = Proc.new do
      msg = outgoing.shift
      chan = multiplex_channels[rand(multiplex_channels.size)]
      Firehose::Client::Producer::Http.new.publish(msg).to(chan) do
        EM::add_timer(rand*0.005) { publish_multi.call } unless outgoing.empty?
      end
    end

    multiplexed_websocket = Proc.new do |cid|
      ws = Faye::WebSocket::Client.new("ws://#{uri.host}:#{uri.port}/channels@firehose?subscribe=#{subscription_query}")

      ws.onmessage = lambda do |event|
        frame = JSON.parse(event.data, :symbolize_names => true)
        received[cid] << frame[:message]
        succeed.call cid unless received[cid].size < messages.size
      end

      ws.onclose = lambda do |event|
        ws = nil
      end

      ws.onerror = lambda do |event|
        raise 'ws failed' + "\n" + event.inspect
      end
    end

    em 180 do
      # Start the clients.
      multiplexed_http_long_poll.call(5)
      multiplexed_http_long_poll.call(6)
      multiplexed_websocket.call(7)
      multiplexed_websocket.call(8)

      # Wait a sec to let our clients set up.
      em.add_timer(1){ publish_multi.call }
    end

    # When EM stops, these assertions will be made.
    expect(received.size).to eql(4)
    received.each_value do |arr|
      expect(arr.size).to be <= messages.size
      # expect(arr.sort).to eql(messages.sort)
    end
  end


  it "returns 400 error for long-polling when using http long polling and sequence header is < 0" do
    em 5 do
      http = EM::HttpRequest.new(http_url).get(:query => {'last_message_sequence' => -1})
      http.errback { |e| raise e.inspect }
      http.callback do
        expect(http.response_header.status).to eql(400)
        em.stop
      end
    end
  end
end
