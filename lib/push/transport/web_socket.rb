require 'em-websocket'

module Push::Transport
  class WebSocket
    include Push::Logger

    Port = 8080
    Host = '0.0.0.0'

    attr_accessor :connection, :consumer

    def initialize(connection, subscription)
      @connection, @subscription = connection, subscription
    end

    def bind
      connection.onclose { unbind }
      subscription.on_message {|m| connection.send m }
    end

    # When this thing dies, delete all of the queues
    def unbind
      subscription.delete
    end

    # TODO this is screwy louie -- I need to be able to mount this into a web context so that 
    # I can access the WS stuff by a path. That path is the channel that the consumer wnats
    # to listen to. Yep, I'll need a multiplex channel, but its cool jeeves. You'll need a class
    # above this that handles the connection loop for WS, and that my friend ,that is what
    # you'll need to mount inside of the dispatcher.
    def self.start(port=Port, host=Host)
      EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
        ws.onopen {
          # TODO how do you extract the channels out of a WS context? It should be
          # accessed via Rack PATH_INFO.
          channel = '/fun'
          new(ws, Consumer.new.subscribe(channel)).bind
        }
      end
    end
  end
end