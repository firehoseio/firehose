require "push/version"

require 'goliath'
require 'goliath/websocket'
require 'amqp'
require 'securerandom'

module Push
  class Subscription
    attr_reader :sid

    def initialize(sid=nil)
      @sid = sid || self.class.sid
    end

    def subscribe(path, &block)
      queue_name  = "#{sid}@#{path}"
      channel     = AMQP::Channel.new(self.class.connection).prefetch(1)
      exchange    = AMQP::Exchange.new(channel, :fanout, path, :auto_delete => true)
      queue       = AMQP::Queue.new(channel, queue_name, :arguments => {'x-expires' => ttl})
      queue.bind(exchange)

      # When we get a message, we want to remove the consumer from the queue so that the x-expires
      # ttl starts ticking down. On the reconnect, the consumer connects to the queue and resets the
      # timer on x-expires... in theory at least.
      @consumer = AMQP::Consumer.new(channel, queue, sid)
      @consumer.on_delivery do |metadata, payload|
        p [:get, sid, @consumer.consumer_tag, path, payload]
        metadata.ack
        block.call(payload)
      end.consume
    end

    def unsubscribe
      @consumer.cancel if @consumer
    end

    def ttl
      15000
    end

  protected
    def self.connection
      @connection ||= AMQP.connect
    end

    def self.sid
      SecureRandom.uuid
    end
  end

  class Publisher
    def publish(path, message)
      channel   = AMQP::Channel.new(self.class.connection)
      exchange  = AMQP::Exchange.new(channel, :fanout, path, :auto_delete => true)
      # TODO How do I clean up this exchange at this point? Do I close it somehow or the channel?
      # The exchange just hangs out indefinitely now.
      exchange.publish(message)
      exchange.delete(:if_unused => true)
    end

  protected
    def self.connection
      @connection ||= AMQP.connect
    end
  end

  class WebSocket < Goliath::WebSocket
    use Goliath::Rack::Params

    # TODO hook AMQP up to this.
    def on_open(env)
      path    = env['REQUEST_PATH'].gsub(/^\/ws/, '') # Name of the queue in AMQP we'll be pulling from.
      cid     = params[:cid]

      @subscription = Push::Subscription.new(cid)
      @subscription.subscribe path do |payload|
        env.stream_send(payload)
      end
    end

    def on_close(env)
      @subscription.unsubscribe if @subscription
    end
  end

  class LongPolling < Goliath::API
    use Goliath::Rack::Params

    def response(env)
      method  = env['REQUEST_METHOD'] # We use this to figure out if we're producing or consuming.
      path    = env['REQUEST_PATH'] # Name of the queue in AMQP we'll be pulling from.
      cid     = params[:cid]

      case method
      # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
      # close down the requeust, and the client then reconnects.
      when 'GET'
        subscription = Push::Subscription.new(cid)
        subscription.subscribe path do |payload|
          subscription.unsubscribe
          env.chunked_stream_send(payload)
          env.chunked_stream_close
        end
        chunked_streaming_response(200, 'Content-Type' => 'text/plain')
      # PUT is how we throw messages on to the fan-out queue.
      when 'PUT'
        body = env['rack.input'].read
        p [:put, path, body]
        Push::Publisher.new.publish(path, body)

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

  class App < Goliath::API
    # TODO Figure out how to route this on schema (ws) or HTTP_UGPRADE header... it 
    # all uses HTTP router under the covers, so it should be doable.
    map '/ws/*', Push::WebSocket
    map '/*', Push::LongPolling
  end
end