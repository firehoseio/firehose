module Push
  module Transport
    autoload :HttpLongPoll, 'push/transport/http_long_poll'

    # This is a workaround for a bug in booting this websocket lib with
    # that I documented at https://github.com/imanel/websocket-rack/issues/5
    # In an ideal world, this would also be an autoload entry
    # autoload :WebSocket, 'push/transport/web_socket'
    require 'push/transport/web_socket'

    # Figure out which transport transport we're going to use to service the request.
    class Dispatcher
      def call(env)
        env['HTTP_UPGRADE'] =~ /websocket/i ? self.class.web_socket_handler.call(env) : self.class.http_long_poll_handler.call(env)
      end

      # Create an instance of a HTTP Long Poll Rack app and memoize.
      def self.http_long_poll_handler
        @http_long_poll_handler ||= HttpLongPoll.new
      end

      # Create an instance of a WebSocket Rack app and memoize.
      def self.web_socket_handler
        @web_socket_handler ||= WebSocket.new(:backend => { :debug => true })
      end
    end
  end
end