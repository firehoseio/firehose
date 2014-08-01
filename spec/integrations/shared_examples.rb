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
  let(:ws_url)    { "ws://#{uri.host}:#{uri.port}#{channel}" }
  let(:messages_received) { Hash.new{|h,k| h[k] = []} }


  def websocket(cid, message_count=messages.size, url=ws_url)
    ws = Faye::WebSocket::Client.new(url)

    ws.onopen = lambda do |event|
      ws.send('{"message_sequence":0}')
    end

    ws.onmessage = lambda do |event|
      frame = JSON.parse(event.data, :symbolize_names => true)
      messages_received[cid] << frame[:message]
      @succeed.call cid unless messages_received[cid].size < message_count
    end

    ws.onclose = lambda do |event|
      ws = nil
    end

    ws.onerror = lambda do |event|
      raise 'ws failed' + "\n" + event.inspect
    end
  end


  it "should pub-sub http and websockets" do
    # Setup variables that we'll use after we turn off EM to validate our
    # test assertions.
    outgoing = messages.dup

    # Our WS and Http clients call this when they have received their messages to determine
    # when to turn off EM and make the test assertion at the very bottom.
    @succeed = Proc.new do
      # TODO: For some weird reason the `add_timer` call causes up to 20 seconds of delay after
      #       the test finishes running. However, without it the test will randomly fail with a
      #       "Redis disconnected" error.
      em.add_timer(1) { em.stop } if messages_received.values.all?{|arr| arr.size == messages.size }
    end

    # Setup a publisher
    publish = Proc.new do
      Firehose::Client::Producer::Http.new.publish(outgoing.shift).to(channel) do
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
        messages_received[cid] << frame[:message]
        if messages_received[cid].size < messages.size
          # Add some jitter so the clients aren't syncronized
          EM::add_timer(rand*0.001) { http_long_poll.call cid, frame[:last_sequence] }
        else
          @succeed.call cid
        end
      end
    end

    # Great, we have all the pieces in order, lets run this thing in the reactor.
    em 180 do
      # Start the clients.
      websocket(1)
      websocket(2)
      http_long_poll.call(3)
      http_long_poll.call(4)

      # Wait a sec to let our clients set up.
      em.add_timer(1){ publish.call }
    end

    # When EM stops, these assertions will be made.
    messages_received.size.should == 4
    messages_received.values.each do |arr|
      arr.should == messages
    end
  end


  it "should return 400 error for long-polling when using http long polling and sequence header is < 0" do
    em 5 do
      http = EM::HttpRequest.new(http_url).get(:query => {'last_message_sequence' => -1})
      http.errback { |e| raise e.inspect }
      http.callback do
        http.response_header.status.should == 400
        em.stop
      end
    end
  end

  it "publishes in batches" do

    # Two batches
    batches = [
      {
        "#{channel}/1" => {
          :messages => [{"1st" => "batch"}, {"would" => "have been the body"}],
          :ttl => 90
        },
        "#{channel}/2" => {
          :messages => [{"more" => "data"}, {"that would" => "have been the body"}],
          :ttl => 120
        }
      },
      {
        "#{channel}/1" => {
          :messages => [{"2nd" => "batch"}, {"would" => "have been the body"}],
          :ttl => 90
        },
        "#{channel}/2" => {
          :messages => [{"more" => "data"}, {"that would" => "have been the body"}],
          :ttl => 120
        }
      }
    ]

    publish = Proc.new do
      Firehose::Client::Producer::Http.new.batch_publish(batches.shift) do |response|
        EM::add_timer(0.05) { publish.call } unless batches.empty?
      end
    end

    @succeed = Proc.new do
      em.add_timer(1) { em.stop } if messages_received.values.all?{|arr| arr.size == 4 }
    end

    # Great, we have all the pieces in order, lets run this thing in the reactor.
    em 20 do
      # Start the clients.
      websocket(1, 4, "#{ws_url}/1")
      websocket(2, 4, "#{ws_url}/2")

      # Wait a sec to let our clients set up.
      em.add_timer(1){ publish.call }
    end

    # When EM stops, these assertions will be made.
    messages_received.size.should == 2
    messages_received.values.each do |msgs|
      # Both clients should have received 4 messages.
      msgs.size.should == 4
    end
  end
end
