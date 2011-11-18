# TODO
#
# 1. Deal with clients that time-out, come back around for a 
#    new subscription, and haven't unsubscribed from the last connection
#
# 2. Figure out why all of the queue connections get killed/cancelled _in development env_
#

require 'sinatra/base'
require 'sinatra/async'

module Push::Transport::Controller
  class HttpLongPoll < Sinatra::Base
    set :root, File.expand_path('../http_long_poll', __FILE__)

    include Push::Logging
    
    register Sinatra::Async

    SidHttpKey = 'HTTP_X_SID'.freeze
    SidParamKey = 'sid'.freeze

    # This is our iframe cross-domain magic proxy that makes long polling work in all of our browsers.
    get '/_xdr_proxy' do
      erb :proxy
    end

    aget %r{.+} do # Match EVERYTHING!
      content_type 'application/json'
      headers 'X-Http-Next-Request' => '0'
      
      # This is suppose to unsubscribe the queue when the client times-out the connection. Without 
      # this, you'd keep queue subscriptions open and things would get messy.
      on_close { 
        log "Closing connection"
        kill_queue
      }
      
      # We use this for a client-side heart beat. The client should hear this request and reconnect
      # after a time-out.
      log "TIMEOUT: #{ Push.config.long_poll.timeout }"
      EventMachine::add_timer(Push.config.long_poll.timeout){
        log "Timeout"
        kill_queue
        ahalt 204 # HTTP Code 204 - No Content. Don't send a 400 level error as FF XHR doesn't pass it properly thru
      }

      # What for a message to come through, pop it, then close down the connection to do it all over again.
      # The rabbit-mq server maintains state between requests with the Push.amqp.queue_ttl attribute.
      log "Subscribed to `#{exchange}`"
      queue.bind(channel.fanout(exchange)).subscribe(:ack => true) {|header, message|
        log "Received message on `#{exchange}`"
        @unsubscribed = true
        queue.unsubscribe {
          log "Unsubscribing from `#{exchange}`"
          header.ack
          log "Acked `#{exchange}`"
          channel.close {
            log "Closed channel `#{exchange}`"
            body {
              log "Flushing out body `#{exchange}`"
              message
            }
          }
        }
      }
    end

  private
    def javascript_include_tag(*scripts)
      scripts.map{|script| %{<script type="text/javascript" src="#{request.script_name}/assets/javascripts/#{script.split(/\.js$/).first}.js"></script>} }.join("\n")
    end

    def log(message)
      logger.debug "Push #{sid}: #{message}"
    end

    def queue
      @queue ||= channel.queue("#{sid}@#{exchange}", :arguments => {'x-expires' => Push.config.amqp.queue_ttl * 1000}) # RabbitMQ wants milliseconds
    end
    
    def exchange
      @exchange ||= env['PATH_INFO']
    end
    
    def channel
      # The prefetch tells AMQP that we only want to grab one message at most when we connect to the queue. This prevents
      # messages from being dropped or not ack'ed when the client comes back around to reconnect.
      @channel ||= ::AMQP::Channel.new(self.class.connection).prefetch(1)
    end

    def self.connection
      @connection ||= AMQP.connect(Push.config.amqp.to_hash)
    end
    
    def kill_queue
      unless @unsubscribed
        @unsubscribed = true
        log "Unsubscribing from `#{exchange}`"
        queue.unsubscribe {
          channel.close {
            log "Channel closed on close"
          }
        }
      end
    end

    def sid
      @sid ||= env[SidHttpKey] || params[SidParamKey] || UUID.new.generate
    end
  end
end