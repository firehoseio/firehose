require 'eventmachine'
require 'em-http'

url = 'http://localhost:5000/a'
messages = (1..1000).map{|n| "msg-#{n}"}
messages_deliveries = 0
cid = rand(99999)
in_flight_messages = []

# mps = messages per second
producer_mps = 50
consumer_mps = 50

EM.run{
  started_at = Time.now

  producer = Proc.new{
    msg = messages.shift
    # PUT the message on the fan-out queue so that a consumer can get it.
    http = EM::HttpRequest.new(url).put(:body => msg)
    http.callback {
      # Put the msg on our in-flight messages so we can make sure we get them all on the other side.
      in_flight_messages << msg
      p [:sent_payload, msg, http.response_header.status]
      # Call the consumer again after a delay so that we can put another message on the queue.
      EM::add_timer(1.0/producer_mps){ producer.call } unless messages.empty?
    }.errback{
      p [:producer_error, msg]
    }
  }

  # Simulate a web browser that's long-polling for responses.
  client = Proc.new{
    http = EM::HttpRequest.new(url).get(:query => {'cid' => cid})
    http.callback {
      msg = http.response
      in_flight_messages.delete msg # This message is no longer in flight, so take it off of there.
      p [:receieved_payload, msg, :delivery, messages_deliveries+=1]
      if in_flight_messages.empty? and messages.empty? 
        # Stop everything and display a success message if everything makes it through.
        EM.stop
        p [:messages_deliveries, messages_deliveries, :messages_per_second, (messages_deliveries/(Time.now - started_at))]
      else
        # Close the connection down and reconnect so that we can get more messages.
        p [:waiting_for_messages, in_flight_messages.size]
        EM::add_timer(1.0/consumer_mps){ client.call }
      end
    }.errback {
      EM.stop
      p [:consumer_error, :inflight_messages, in_flight_messages]
    }
  }

  # Fire up the client to start listening for messages
  client.call

  # Let the client warm-up and connect to AMQP, then start firing off messages into the queue
  EM.add_timer(1) { producer.call }

}