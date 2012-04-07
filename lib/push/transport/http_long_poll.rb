require 'eventmachine'

module Push::Transport
  class HttpLongPoll
    # Setup the rack application with a consumer that can be connected to the front-end for processing.
    def initialize(config=nil)
      @config = config || Configuration.new
    end

    # Process the Rack request with a streaming response with the consumer.
    def call(env)
      Stream.response env, @config.timeout do |stream|
        subscription = @config.consumer(env).subscription(@config.channel(env))
        stream.on_close {
          subscription.delete
        }
        subscription.on_message {|message, consumer|
          subscription.delete
          stream.halt 200, {}, [message]
        }
        stream.on_timeout {
          stream.halt 204, {}, []
        }
        subscription.subscribe
      end
    end
  end

  # Encapsulate a streaming response for a rack environment
  class HttpLongPoll::Stream
    include Push::Logging

    attr_reader :env, :timeout

    # Thin and Rainbows recognizes this response and defers the request.
    AsyncResponse = [-1, {}, []].freeze
    # Async callback key as specified by rack.
    AsyncCallback = 'async.callback'.freeze
    # This key is defined by Rack to run a block when the connection is closed.
    AsyncClose = 'async.close'.freeze
    # Lets store the response stream in a key so we can get at it from tests
    ResponseStream = 'push.stream'

    def initialize(env, timeout=nil, &block)
      @env, @timeout = env, timeout
      logger.debug "Stream initializing"
      block.call self if block
      # Set a reference to this in the rack environment so that we can run test 
      # assertions on it
      env[ResponseStream] = self
      # Start a timer if a timeout paramter is given; otherwise forget it! We'll
      # let the server deal with timeouts.
      start_timeout if timeout
      logger.debug "Stream initialized"
    end

    # Flush out the response.
    def halt(status=200, headers={}, body=[])
      env[AsyncCallback].call([status, headers, body])
    end

    def on_close(&block)
      env[AsyncClose] = EventMachine::DefaultDeferrable.new
      env[AsyncClose].callback {
        cancel_timeout
        logger.debug "Stream closing"
        block.call
        logger.debug "Stream closed"
      }
    end

    def on_timeout(&block)
      @on_timeout = block
    end

    def start_timeout
      @timeout_timer = EM.add_timer(timeout.to_f) {
        logger.debug "Stream timed-out"
        @on_timeout.call
      }
    end

    def cancel_timeout
      if timeout and @timeout_timer
        EM.cancel_timer @timeout_timer
      end
    end

    # Create an instance of a stream, then defer tell the server that the response 
    # will be deferred
    def self.response(*args, &block)
      new(*args, &block)
      AsyncResponse
    end
  end
end