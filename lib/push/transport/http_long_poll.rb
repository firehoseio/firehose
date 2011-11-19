module Push::Transport
  class HttpLongPoll
    # Backend that will be bound to the front-end for grabbing the connection.
    attr_reader :backend

    # Setup the rack application with a backend that can be connected to the front-end for processing.
    def initialize(backend)
      @backend = backend
    end

    # Process the Rack request with a streaming response with the backend.
    def call(env)
      Stream.response(env, backend)
    end
  end

  # Encapsulate a streaming response for a rack environment
  class HttpLongPoll::Stream
    attr_reader :env

    # Raise this exception if streaming isn't supported on the web server
    NotSupported = Class.new(RuntimeError)
    # Thin and Rainbows recognizes this response and defers the request.
    AsyncResponse = [-1, {}, []].freeze
    # Async callback key as specified by rack.
    AsyncCallback = 'async.callback'.freeze
    # This key is defined by Rack to run a block when the connection is closed.
    AsyncClose = 'async.close'.freeze
    # How long should we keep the connection open before gracefully timing out?
    Timeout = 30
    # Send an HTTP 204 - No Content response if the long poll times out
    TimeoutResponse = [204, {}, []].freeze

    def initialize(env, backend)
      @env = env

      # Bang out of here if the server doesn't support streaming
      assert_async_support

      # Setup a timer that sends out a blank response after a certain amount of time
      on_timeout do
        halt *TimeoutResponse
      end

      # Make sure we clean up the subscription when we close out the connection.
      on_close do
        backend.unsubscribe
      end

      # Subscribe to the backend and wait for a message
      backend.subscribe do |message|
        cancel_timeout
        backend.unsubscribe # We only want one message, so unsub and write it out
        halt 200, {}, message
      end
    end

  private
    # Flush out the response.
    def halt(status=200, headers={}, body=[])
      env[AsyncCallback].call([status, headers, body])
    end

    # Start a timer that runs the block after `timeout` seconds
    def on_timeout(timeout=Timeout, &block)
      @timer = EventMachine::add_timer(timeout, &block)
    end

    # Cancels the timeout timer of one was set.
    def cancel_timeout
      @timer.cancel if @timer
    end

    def on_close(&block)
      env[AsyncClose] = block
    end

    # Make sure the server supports async responses; otherwise blow the thing up.
    def assert_async_support
      raise NotSupported unless env.include? AsyncCallback
    end

    # Create an instance of a stream, then defer tell the server that the response 
    # will be deferred
    def self.response(*args)
      new(*args)
      return AsyncResponse
    end
  end
end

  # class HttpLongPoll < Sinatra::Base
  #   set :root, File.expand_path('../http_long_poll', __FILE__)

  #   include Push::Logging
    
  #   register Sinatra::Async

  #   SidHttpKey = 'HTTP_X_SID'.freeze
  #   SidParamKey = 'sid'.freeze

  #   # This is our iframe cross-domain magic proxy that makes long polling work in all of our browsers.
  #   get '/_xdr_proxy' do
  #     erb :proxy
  #   end

  #   aget %r{.+} do # Match EVERYTHING!
  #     content_type 'application/json'
  #     headers 'X-Http-Next-Request' => '0'
      
  #     # This is suppose to unsubscribe the queue when the client times-out the connection. Without 
  #     # this, you'd keep queue subscriptions open and things would get messy.
  #     on_close { 
  #       log "Closing connection"
  #       kill_queue
  #     }
      
  #     # We use this for a client-side heart beat. The client should hear this request and reconnect
  #     # after a time-out.
  #     log "TIMEOUT: #{ Push.config.long_poll.timeout }"
  #     EventMachine::add_timer(Push.config.long_poll.timeout){
  #       log "Timeout"
  #       kill_queue
  #       ahalt 204 # HTTP Code 204 - No Content. Don't send a 400 level error as FF XHR doesn't pass it properly thru
  #     }

  #     # What for a message to come through, pop it, then close down the connection to do it all over again.
  #     # The rabbit-mq server maintains state between requests with the Push.amqp.queue_ttl attribute.
  #     log "Subscribed to `#{exchange}`"
  #     queue.bind(channel.fanout(exchange)).subscribe(:ack => true) {|header, message|
  #       log "Received message on `#{exchange}`"
  #       @unsubscribed = true
  #       queue.unsubscribe {
  #         log "Unsubscribing from `#{exchange}`"
  #         header.ack
  #         log "Acked `#{exchange}`"
  #         channel.close {
  #           log "Closed channel `#{exchange}`"
  #           body {
  #             log "Flushing out body `#{exchange}`"
  #             message
  #           }
  #         }
  #       }
  #     }
  #   end

  # private
  #   def javascript_include_tag(*scripts)
  #     scripts.map{|script| %{<script type="text/javascript" src="#{request.script_name}/assets/javascripts/#{script.split(/\.js$/).first}.js"></script>} }.join("\n")
  #   end

  #   def log(message)
  #     logger.debug "Push #{sid}: #{message}"
  #   end

  #   def queue
  #     @queue ||= channel.queue("#{sid}@#{exchange}", :arguments => {'x-expires' => Push.config.amqp.queue_ttl * 1000}) # RabbitMQ wants milliseconds
  #   end
    
  #   def exchange
  #     @exchange ||= env['PATH_INFO']
  #   end
    
  #   def channel
  #     # The prefetch tells AMQP that we only want to grab one message at most when we connect to the queue. This prevents
  #     # messages from being dropped or not ack'ed when the client comes back around to reconnect.
  #     @channel ||= ::AMQP::Channel.new(self.class.connection).prefetch(1)
  #   end

  #   def self.connection
  #     @connection ||= AMQP.connect(Push.config.amqp.to_hash)
  #   end
    
  #   def kill_queue
  #     unless @unsubscribed
  #       @unsubscribed = true
  #       log "Unsubscribing from `#{exchange}`"
  #       queue.unsubscribe {
  #         channel.close {
  #           log "Channel closed on close"
  #         }
  #       }
  #     end
  #   end

  #   def sid
  #     @sid ||= env[SidHttpKey] || params[SidParamKey] || UUID.new.generate
  #   end
  # end
# end