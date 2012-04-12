require "push/version"
require 'goliath'
require 'amqp'
require 'securerandom'

module Push
  class LongPolling < Goliath::API
    use Goliath::Rack::Params

    def response(env)
      method  = env['REQUEST_METHOD'] # We use this to figure out if we're producing or consuming.
      path    = env['REQUEST_PATH'] # Name of the queue in AMQP we'll be pulling from.
      ttl     = 15000 # Keep messages in a RabbitMQ queue for 15s before killing all of them.
      cid     = params[:cid] || SecureRandom.uuid # And ID for the web client.

      case method
      # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
      # close down the requeust, and the client then reconnects.
      when 'GET'
        queue_name  = "#{cid}@#{path}"
        channel     = AMQP::Channel.new(self.class.connection).prefetch(1)
        exchange    = AMQP::Exchange.new(channel, :fanout, path, :auto_delete => true)
        queue       = AMQP::Queue.new(channel, queue_name, :arguments => {'x-expires' => ttl})
        queue.bind(exchange)

        # When we get a message, we want to remove the consumer from the queue so that the x-expires
        # ttl starts ticking down. On the reconnect, the consumer connects to the queue and resets the
        # timer on x-expires... in theory at least.
        consumer = AMQP::Consumer.new(channel, queue, cid)
        consumer.on_delivery do |metadata, payload|
          p [:get, cid, consumer.consumer_tag, path, payload]

          metadata.ack
          consumer.cancel
          env.chunked_stream_send(payload)
          env.chunked_stream_close
        end.consume

        chunked_streaming_response(200, 'Content-Type' => 'text/plain')

      # PUT is how we throw messages on to the fan-out queue.
      when 'PUT'
        body      = env['rack.input'].read
        channel   = AMQP::Channel.new(self.class.connection)
        exchange  = AMQP::Exchange.new(channel, :fanout, path, :auto_delete => true)

        p [:put, path, body]

        # TODO How do I clean up this exchange at this point? Do I close it somehow or the channel?
        # The exchange just hangs out indefinitely now.
        exchange.publish(body)

        [202, {}, []]
      else
        [501, {}, ["#{method} not supported."]]
      end
    end

  private
    def self.connection
      @connection ||= AMQP.connect
    end
  end
end