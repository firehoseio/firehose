module Push
  module Transport
    autoload :HttpLongPoll, 'push/transport/http_long_poll'
    autoload :WebSocket,    'push/transport/web_socket'

    # Figure out which transport transport we're going to use to service the request.
    class Dispatcher
      def call(env)
        env['HTTP_UPGRADE'] == 'websocket' ? WebSocket.new.call(env) : HttpLongPoll.new.call(env)
      end
    end
  end
end