require 'spec_helper'
require 'rack/test'
require 'em-ventually/rspec'
require 'logger'

describe Push::Transport::HttpLongPoll do
  before(:all) do
    @backend = Push::Backend::Test.new
  end

  def app
    Push::Transport::HttpLongPoll.new do |c|
      c.timeout = 5
      c.consumer_id do |env| # Extract out a session_id here. Could be from a cookie or a header.
        env['HTTP_X_CONSUMER_ID']
      end
    end
  end

  context "rack" do
    include Rack::Test::Methods

    it "should extract consumer_id from env" do
      get '/', {}, {'HTTP_X_CONSUMER_ID' => 10}
      last_request.env['push.stream'].consumer.id.should eql(10)
    end
  end

  context "streaming" do
    context "successful request" do
      it "should be a 200 status code" do
        message, channel = 'hooowdy', '/thin/10'

        Push::Test.thin(app) do |server, http|
          http.get('/1', :headers => {'HTTP_X_CONSUMER_ID' => 'brad'}) {|resp|
            ly(200){ resp.response_header.status }
          }
        end
        Push::Backend::AMQP.new.publish(message, channel)
      end

      it "should have message body" do
        message, channel = 'hooowdy', '/thin/10'

        Push::Test.thin(app) do |server, http|
          http.get(channel, :headers => {'HTTP_X_CONSUMER_ID' => 'brad'}) {|resp|
            ly(message){ resp.response }
          }
        end
        Push::Backend::AMQP.new.publish(message, channel)
      end
    end

    it "should timeout and return a 204" do
      Push::Test.thin(app) do |server, http|
        http.get('/1', :headers => {'HTTP_X_CONSUMER_ID' => 'brad'}) {|resp|
          ly(204){ resp.response_header.status }
        }
      end
    end
  end
end