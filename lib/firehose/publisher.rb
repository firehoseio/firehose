module Firehose
  class Publisher
    def publish(path, message)
      channel   = AMQP::Channel.new(Firehose.amqp.connection)
      exchange  = AMQP::Exchange.new(channel, :fanout, path, :auto_delete => true)
      # TODO How do I clean up this exchange at this point? Do I close it somehow or the channel?
      # The exchange just hangs out indefinitely now.
      exchange.publish(message)
      exchange.delete(:if_unused => true)
    end
  end
end