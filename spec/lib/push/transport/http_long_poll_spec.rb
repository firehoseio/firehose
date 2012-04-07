require 'spec_helper'
require 'rack/test'

describe Push::Transport::HttpLongPoll do
  include Push::Test::AMQP

  let(:channel){ amqp.next_channel }
  let(:backend){ Push::Backend.new }
  let(:config) {
    config = Push::Transport::Configuration.new 
    config.timeout = 2
    config.consumer = Proc.new{|env| Push::Consumer.new Rack::Request.new(env).params['cid']}
    config
  }
  let(:app){
    Push::Transport::HttpLongPoll.new config
  }

  context "streaming" do
    context "successful request" do
      it "should be a 200 status code" do
        sent, received = 'hooowdy', nil
        response_status = nil

        em do
          Push::Test.thin(app) do |http|
            http.get(channel) {|resp|
              response_status = resp.response_header.status
              EM.stop
            }
          end

          EM.add_timer(1) do
            backend.publish(sent, channel)
          end
        end

        response_status.should eql(200)
      end

      it "should keep the consumer queue around between request cycles" do
        sent, received, requests = (0..500).map(&:to_s), [], 0
        
        em 20 do
          Push::Test.thin(app) do |http|
            request = Proc.new {
              http.get("#{channel}?r=#{requests+=1}&cid=brad") {|resp|
                received << resp.response
                # Trigger n long-poll requests.
                requests < sent.size ? request.call : EM.stop
              }
            }
            request.call
          end

          EM.add_timer(1) do
            # Drop messages into zie queue
            sent.each do |message|
              backend.publish(message, channel)
            end
          end
        end

        received.should include(sent)
      end
    end
  end

  it "should timeout and return a 204" do
    response_status = nil

    em do
      Push::Test.thin(app) do |http|
        http.get('/timeout/land', :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
          response_status = resp.response_header.status
          EM.stop
        }
      end
      backend.publish('message', channel) # If we don't publish a message and close AMQP, it will stupidly complain.
    end

    response_status.should eql(204)
  end
end