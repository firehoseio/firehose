require 'spec_helper'

describe Firehose::Rack do
  include EM::TestHelper

  before(:all) do
    Firehose::Producer.adapter = :em_http
  end

  after(:all) do
    Firehose::Producer.adapter = nil
  end

  let(:app)       { Firehose::Rack::App.new }
  let(:messages)  { (1..2000).map{|n| "msg-#{n}" } }
  let(:channel)   { "/firehose/integration/#{Time.now.to_i}" }
  let(:uri)       { Firehose::Default::URI }
  let(:http_url)  { "http://#{uri.host}:#{uri.port}#{channel}" }
  let(:ws_url)    { "ws://#{uri.host}:#{uri.port}#{channel}" }

  it "should pub-sub http and websockets" do
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
      Firehose::Producer.new.publish(outgoing.shift).to(channel) do
        # The random timer ensures that sometimes the clients will be behind
        # and sometimes they will be caught up.
        EM::add_timer(rand*0.005) { publish.call } unless outgoing.empty?
      end
    end

    # Lets have an HTTP Long poll client
    http_long_poll = Proc.new do |cid, last_sequence|
      http = EM::HttpRequest.new(http_url).get(:head => {'Last-Message-Sequence' => last_sequence})
      http.errback { em.stop }
      http.callback do
        received[cid] << http.response
        if received[cid].size < messages.size
          # Add some jitter so the clients aren't syncronized
          EM::add_timer(rand*0.001) { http_long_poll.call cid, http.response_header['Last-Message-Sequence'] }
        else
          succeed.call cid
        end
      end
    end

    # And test a web socket client too, at the same time.
    websocket = Proc.new do |cid|
      ws = EventMachine::WebSocketClient.connect(ws_url)
      ws.errback  { raise 'ws failed' }
      ws.stream do |msg|
        received[cid] << msg
        succeed.call cid unless received[cid].size < messages.size
      end
    end

    # Great, we have all the pieces in order, lets run this thing in the reactor.
    em 60 do
      # Start the server
      server = ::Thin::Server.new('0.0.0.0', uri.port, app)
      server.start

      # If the 1st request is a ws request, then (it seems) the ws handshake
      # won't work. This dummy request overcomes that.
      # Note that this dummy request uses an invalid sequence number. That is
      # to be sure the request returns immediately rather than waiting for a
      # timeout because there is no data.
      http = EM::HttpRequest.new(http_url).get(:head => {'Last-Message-Sequence' => -1})
      http.errback { |e| raise 'dummy request failed: ' + e.inspect }
      http.callback do
        # The dummy request finished, so the server can now accept ws requests.

        # Start the clients.
        websocket.call(1)
        websocket.call(2)
        http_long_poll.call(3)
        http_long_poll.call(4)

        # Wait a sec to let our clients set up.
        em.add_timer(1){ publish.call }
      end
    end

    # When EM stops, these assertions will be made.
    received.size.should == 4
    received.values.each do |arr|
      arr.should == messages
    end
  end


  it "should return 400 error for long-polling when using http long polling and sequence header is < 0" do
    em 5 do
      server = ::Thin::Server.new('0.0.0.0', uri.port, app)
      server.start

      http = EM::HttpRequest.new(http_url).get(:head => {'Last-Message-Sequence' => -1})
      http.errback { |e| raise e.inspect }
      http.callback do
        http.response_header.status.should == 400
        em.stop
      end
    end
  end
end
