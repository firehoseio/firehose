require 'spec_helper'
require 'rack/test'

describe Push::Transport::HttpLongPoll do
  include Push::Test::AMQP

  def app
    config = Push::Transport::Configuration.new
    config.timeout = 3
    Push::Transport::HttpLongPoll.new config
  end

  context "rack" do
    # include Rack::Test::Methods

    # it "should extract consumer_id from env" do
    #   get '/', {}, {'HTTP_CONSUMER_ID' => 10}
    #   last_request.env['push.consumer'].id.should eql(10)
    # end
  end

  context "streaming" do
    context "successful request" do
      it "should be a 200 status code" do
        message, channel = 'hooowdy', '/thin/10'

        em do
          Push::Test.thin(app) do |server, http|
            http.get(channel, :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
              @response_status = resp.response_header.status
              EM.stop
            }
          end
          EM.add_timer(1){
            Push::Backend.new.publish(message, channel)
          }
        end

        @response_status.should eql(200)
      end

      it "should have message body" do
        message, channel = 'duuuude', '/thin/11'

        em do
          Push::Test.thin(app) do |server, http|
            http.get(channel, :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
              @message = resp.response
            }
          end
          EM.add_timer(1){
            Push::Backend.new.publish(message, channel)
          }
        end

        message.should eql(@message)
      end
    end

    it "should timeout and return a 204" do
      em do
        Push::Test.thin(app) do |server, http|
          http.get('/never/ending/stream', :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
            @response_status = resp.response_header.status
          }
        end
        Push::Backend.new.publish('message', '/never/never/land')
      end
      @response_status.should eql(204)
    end
  end
end