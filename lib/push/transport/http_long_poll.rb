require 'eventmachine'

module Push::Transport
  class HttpLongPoll
    # Backend that will be bound to the front-end for grabbing the connection.
    attr_accessor :consumer, :timeout

    # Setup the rack application with a consumer that can be connected to the front-end for processing.
    def initialize(&block)
      block.call self if block
    end

    # Process the Rack request with a streaming response with the consumer.
    def call(env)
      Stream.response(env) do |s|
        s.consumer = Push::Consumer.new do |c|
          c.id = consumer_id.call(env) if consumer_id
        end
        s.timeout = timeout
      end
    end

    # If a block is given, set the code that will extract the consumer_id out of the
    # rack env hash. The consumer_id may be stored in a cookie, on a memcached key, or
    # whatever.
    def consumer_id(&block)
      block ? @consumer_id = block : @consumer_id
    end
  end

  # Encapsulate a streaming response for a rack environment
  class HttpLongPoll::Stream
    attr_reader :env
    attr_accessor :consumer, :timeout

    include Push::Logging

    # How long should we keep the connection open before gracefully timing out?
    Timeout = 30
    # Thin and Rainbows recognizes this response and defers the request.
    AsyncResponse = [-1, {}, []].freeze
    # Async callback key as specified by rack.
    AsyncCallback = 'async.callback'.freeze
    # This key is defined by Rack to run a block when the connection is closed.
    AsyncClose = 'async.close'.freeze
    # Lets store the response stream in a key so we can get at it from tests
    ResponseStream = 'push.stream'

    def initialize(env, &block)
      @env = env

      yield self if block_given?

      # Set a reference to this in the rack environment so that we can run test 
      # assertions on it
      env[ResponseStream] = self

      # Make sure we clean up the subscription when we close out the connection.
      on_close do
        cancel_timeout
        @subscription.delete if @subscription
        logger.info "HTTP closed"
      end

      # Setup a timer that sends out a blank response after a certain amount of time
      on_timeout do
        logger.info "HTTP timed-out"
        # Unsubscribe is handled by the on_close callback
        halt 204, {}, []
      end

      # Subscribe to the consumer and wait for a message
      @subscription = consumer.subscribe(channel) do |message|
        cancel_timeout
        logger.debug "Publishing `#{message}`"
        halt 200, {}, [message]
      end
    end

    def timeout
      @timeout || Timeout
    end

    def consumer
      @consumer || Push::Consumer.new
    end

    # The URL path is the path for the channel
    def channel
      env['PATH_INFO']
    end

  private
    # Flush out the response.
    def halt(status=200, headers={}, body=[])
      env[AsyncCallback].call([status, headers, body])
    end

    # Start a timer that runs the block after `timeout` seconds
    def on_timeout(&block)
      @timer = EventMachine::Timer.new(timeout){
        logger.debug "Timed out `#{channel}`"
        block.call
      }
    end

    # Cancels the timeout timer of one was set.
    def cancel_timeout
      if @timer
        @timer.cancel
        logger.debug "Timeout canceled"
      end
    end

    def on_close(&block)
      env[AsyncClose] = EventMachine::DefaultDeferrable.new
      env[AsyncClose].callback { block.call }
    end

    # Create an instance of a stream, then defer tell the server that the response 
    # will be deferred
    def self.response(env, *args, &block)
      new(env, *args, &block)
      AsyncResponse
    end
  end
end