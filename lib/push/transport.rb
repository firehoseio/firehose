module Push
  module Transport
    module Controller
      autoload :HttpLongPoll, 'push/transport/controller/http_long_poll'
      autoload :WebSocket,    'push/transport/controller/web_socket'
    end

    # Figure out which transport controller we're going to use to service the request.
    class Dispatcher
      def call(env)
        env['Upgrade'] == 'WebSocket' ? Controller::WebSocket.new.call(env) : Controller::HttpLongPoll.new.call(env)
      end
    end
  end
end