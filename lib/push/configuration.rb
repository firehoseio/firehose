require 'logger'

module Push
  class Configuration
    attr_accessor :amqp, :web_socket, :logger, :backend, :long_poll, :exception_handler

    class AMQP < Struct.new(:host, :port, :username, :password, :vhost, :queue_ttl)
      def to_hash
        {
          :host => Push.config.amqp.host,
          :port => Push.config.amqp.port,
          :user => Push.config.amqp.username,
          :pass => Push.config.amqp.password,
          :vhost => Push.config.amqp.vhost
        }
      end
    end

    WebSocket = Struct.new(:url)
    LongPoll = Struct.new(:url, :timeout)
    
    def backend=(name)
      @backend = name.to_sym
    end

    def initialize
      @amqp = AMQP.new('127.0.0.1', 5672, 'guest', 'guest', '/', 5)
      @web_socket = WebSocket.new('ws://localhost:3000/_push')
      @long_poll = LongPoll.new('http://localhost:3000/_push', 30)
      @backend = :amqp
      @logger = Logger.new($stdout)
      @exception_reporter = Proc.new{|e| logger.error(e) }
    end

    def from_hash(hash)
      # Pick a backend doofus
      self.backend = hash['backend'] if hash['backend']

      # WS setup
      if web_socket = hash['web_socket']
        self.web_socket.url = web_socket['url'] if web_socket['url']
      end
      
      # HTTP longpoll setup
      if long_poll = hash['long_poll']
        self.long_poll.url = long_poll['url'] if long_poll['url']
        self.long_poll.timeout = long_poll['timeout'] if long_poll['timeout']
      end

      # Setup AMQP
      if amqp = hash['amqp']
        %w[host port username password vhost queue_ttl].each do |key|
          self.amqp.send("#{key}=", amqp[key]) if amqp[key]
        end
      end
    end
  end
end