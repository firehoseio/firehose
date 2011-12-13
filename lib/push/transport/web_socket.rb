require 'rack/websocket'

module Push::Transport
  class WebSocket < Rack::WebSocket::Application
    include Push::Logging

    # Subscribe to a path and make some magic happen, mmkmay?
    def on_open(env)
      @subscription = Push::Consumer.new(env['HTTP_CONSUMER_ID']).subscription(env['PATH_INFO'])
      # message[0] is a hack because something is jacked up with the arity of on_message. Figure this 
      # out so that message only returns the payload.
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