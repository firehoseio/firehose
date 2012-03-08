module Push
  class Server
    attr_reader :pub, :sub

    def initialize(&block)
      @sub = Push::Transport::Dispatcher.new(&block)
      @pub = Push::Producer.new
    end

    def call(env)
      req = Rack::Request.new(env)
      if req.post?
        pub.publish(req.body.read).to(req.path)
        [204, {}, []]
      else
        sub.call(env)
      end
    end
  end
end