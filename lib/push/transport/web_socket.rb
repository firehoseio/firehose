require 'rack/websocket'

module Push::Transport
  class WebSocket < Rack::WebSocket::Application
    include Push::Logging
    
    def initialize(config=nil, opts={})
      @config = config || Configuration.new
      super opts
    end

    # Subscribe to a path and make some magic happen, mmkmay?
    def on_open(env)
      @subscription = @config.consumer(env).subscription(@config.channel(env))
      @subscription.on_message {|message, consumer| send_data message }
      @subscription.subscribe
    end

    # Delete the subscription if the thing even happened.
    def on_close(env)
      @subscription.delete if @subscription
      logger.debug "WebSocket closing connection"
    end

    # Log websocket level errors
    def on_error(env, error)
      logger.debug "Websocket error: #{error.message}"
    end
  end
end