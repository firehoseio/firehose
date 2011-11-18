module Push::Transport::Controller
  class WebSocket < Cramp::Websocket
    include Push::Logger

    on_start :bind_queue
    on_finish :unbind_queue
    on_data :message_received
    
    def bind_queue
      logger.info "Subscribed to '#{exchange}'"
      queue.bind(channel.fanout(exchange)).subscribe(:ack => true) {|header, message|
        header.ack
        render message
        logger.info "Sent message: #{message}"
      }
    end
    
    def unbind_queue
      queue.unsubscribe {
        channel.close
        logger.info "Unsubscribed from '#{exchange}'"
      }
    end
    
    def message_received(data)
      logger.info "Received #{data}" # Who cares? Do nothing.
    end
    
  private
    def channel
      @channel ||= AMQP::Channel.new
    end
    
    def queue
      @queue ||= channel.queue("#{sid}@#{exchange}", :arguments => {'x-expires' => Push.config.amqp.queue_ttl})
    end
    
    def sid
      @sid ||= UUID.new.generate
    end
    
    def exchange
      request.env['PATH_INFO']
    end
  end
end