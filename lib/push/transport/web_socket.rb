require 'rack/websocket'

module Push::Transport
  class WebSocket < Rack::WebSocket::Application
    include Push::Logger

    # class Handler
    #   def initialize(socket, env)
    #     @socket, @env = socket, env
    #     consumer.subscribe_to(env['PATH_INFO']) do |s|
    #       socket.on_close { subscription.delete }
    #     end
    #   end
    # end

    def initialize(connection, subscription)
      @connection, @subscription = connection, subscription
    end

    # Subscribe to a path and make some magic happen, mmmkay?
    def on_open(env)
      Push::Consumer.new(env['X_HTTP_CONSUMER_ID']).subscribe_to(env['PATH_INFO']) do |s|
        on_close { subscription.delete }
        s.on_message {|m| send_data m }
      end
    end

    # def on_close(env)
    # end

    # def on_message(message, env)
    # end

    # def on_error(env, error)
    #   puts "Error occured: " + error.message
    # end
  end
end