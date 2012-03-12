require 'spec_helper'
require 'rack/test'

describe Push::Transport::HttpLongPoll do
  include Push::Test::AMQP

  let(:channel){ amqp.next_channel }
  let(:backend){ Push::Backend.new }
  let(:config) {
    config = Push::Transport::Configuration.new 
    config.timeout = 2
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
          Push::Test.thin(app) do |server, http|
            http.get(channel, :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
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
        sent, received = %w[one two], []
        
        em do
          Push::Test.thin(app) do |server, http|
            http.get(channel, :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
              received << resp.response if resp.response_header.status == 200
              p "uno"
              # ... aaand grab the second message after we close out this connection.
              http.get(channel, :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
                p "dos"
                received << resp.response if resp.response_header.status == 200
                EM.stop
              }
            }
          end

          EM.add_timer(1) do
            # Drop 2 messages into zie queue
            sent.each do |message|
              backend.publish(message, channel)
            end
          end
        end

        received.should =~ sent
      end
    end
  end

  it "should timeout and return a 204" do
    response_status = nil

    em do
      Push::Test.thin(app) do |server, http|
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