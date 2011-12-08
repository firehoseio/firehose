require 'rack/websocket'

module Push::Transport
  class WebSocket < Rack::WebSocket::Application
    include Push::Logging
  
    # Subscribe to a path and make some magic happen, mmmkay?
    def on_open(env)
      @subscription = Push::Consumer.new(env['X_HTTP_CONSUMER_ID']).subscription(env['PATH_INFO'])
      @subscription.on_message {|message|
        send_data message
      }
      @subscription.subscribe
    end

    def on_close(env)
      @subscription.delete if @subscription
      logger.debug "WebSocket closing connection"
    end

    def on_error(env, error)
      logger.debug "Websocket error: #{error.message}"
    end
  end
end