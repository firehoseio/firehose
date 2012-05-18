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
  let(:messages)  { (1..10).map{|n| "msg-#{n}" } }
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
      em.stop if received.values.all?{|arr| arr.size == messages.size }
    end

    # Setup a publisher
    publish = Proc.new do
      Firehose::Producer.new.publish(outgoing.shift).to(channel) do
        publish.call unless outgoing.empty?

        #EM::add_timer(1) { publish.call } unless outgoing.empty?
      end
    end

    # Lets have an HTTP Long poll client
    http_long_poll = Proc.new do |cid, last_sequence|
      http = EM::HttpRequest.new(http_url).get(:head => {'Last-Message-Sequence' => last_sequence})
      http.errback { em.stop }
      http.callback do
        received[cid] << http.response
        if received[cid].size < messages.size
          http_long_poll.call cid, http.response_header['Last-Message-Sequence']
        else
          succeed.call cid
        end
      end
    end

    # And test a web socket client too, at the same time.
    websocket = Proc.new do |cid|
      ws = EventMachine::WebSocketClient.connect(ws_url)
      ws.errback  { em.stop }
      ws.stream do |msg|
        received[cid] << msg
        succeed.call cid unless received[cid].size < messages.size
      end
    end

    # Great, we have all the pieces in order, lets run this thing in the reactor.
    em 15 do
      # Start the server
      server = ::Thin::Server.new('0.0.0.0', uri.port, app)
      server.start

      # Start the http_long_poller.
      # websocket.call(1)
      # websocket.call(2)
      # http_long_poll.call(3)
      http_long_poll.call(4)

      # Wait a sec to let our http_long_poll setup.
      em.add_timer(1){ publish.call }
    end

    # When EM stops, these assertions will be made.
    received.size.should == 1
    received.values.each do |arr|
      arr.should =~ messages
    end
  end
end
