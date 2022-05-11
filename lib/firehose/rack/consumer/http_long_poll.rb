require 'json'

module Firehose
  module Rack
    class Consumer
      class HttpLongPoll
        # How long should we wait before closing out the consuming clients web connection
        # for long polling? Most browsers timeout after a connection has been idle for 30s.
        TIMEOUT = 20

        attr_accessor :timeout

        def initialize(timeout=TIMEOUT)
          @timeout = timeout
          yield self if block_given?
        end

        def call(env)
          if Consumer.multiplexing_request?(env)
            MultiplexingHandler.new(@timeout).call(env)
          else
            DefaultHandler.new(@timeout).call(env)
          end
        end

        class Handler < Firehose::Rack::Consumer::BasicHandler
          include Firehose::Rack::Helpers

          def initialize(timeout=TIMEOUT)
            @timeout = timeout
            yield self if block_given?
          end

          def call(env)
            request = request(env)
            method  = request.request_method

            case method
            # GET is how clients subscribe to the queue. When a messages comes in, we flush out a response,
            # close down the requeust, and the client then reconnects.
            when "GET"
              handle_request(request, env)
              return ASYNC_RESPONSE
            # we use post messages for http long poll multiplexing
            when "POST"
              if Consumer.multiplexing_request?(env)
                handle_request(request, env)
                return ASYNC_RESPONSE
              end
            end

            Firehose.logger.debug "HTTP #{method} not supported"
            response(405, "#{method} not supported.", "Allow" => "GET")
          end

          private

          def request(env)
            env['parsed_request'] ||= ::Rack::Request.new(env)
          end

          def async_callback(env, code, message = "", headers = nil)
            resp_headers = response_headers(env)

            if headers
              resp_headers.merge!(headers)
            end

            if cb = env["async.callback"]
              cb.call response(code, message, resp_headers)
            else
              Firehose.logger.error "async.callback not set for response: #{message.inspect}"
            end
          end

          def respond_async(channel, last_sequence, params, env)
            EM.next_tick do
              if last_sequence < 0
                async_callback env, 400, "The last_message_sequence parameter may not be less than zero"
              else
                begin
                  chan_sub = Server::ChannelSubscription.new(
                    channel,
                    env,
                    params: params,
                    sequence: last_sequence,
                    timeout: @timeout
                  )

                  chan_sub.next_messages.callback do |messages|
                    # TODO: Can we send all of these messages down in one request? Sending one message per
                    # request is slow and inefficient. If we change the protocol (3.0?) we could batch the
                    # messages and send them all down the pipe, then close the conneciton.
                    message = messages.first
                    async_callback env, 200, wrap_frame(channel, message)
                  end.errback do |e|
                    if e == :timeout
                      Firehose::Server.metrics.timeout!(:http_subscribe_multiplexed, channel)
                      async_callback env, 204
                    else
                      Firehose::Server.metrics.error!(:http_subscribe_multiplexed, channel)
                      Firehose.logger.error "Unexpected error when trying to GET last_sequence #{last_sequence} for path #{channel}: #{e.inspect}"
                      async_callback env, 500, "Unexpected error"
                    end
                  end
                rescue Server::ChannelSubscription::Failed => e
                  Firehose::Server.metrics.error!(:http_subscribe_multiplexed_failed, channel)
                  Firehose.logger.info "Subscription failed: #{e.message}"
                  async_callback env,
                                 400,
                                 JSON.generate(error: "Subscription failed",
                                               reason: e.message)
                end
              end
            end
          end
        end

        class DefaultHandler < Handler
          def wrap_frame(channel, message)
            JSON.generate message: message.payload,
                          last_sequence: message.sequence
          end

          def log_request(path, last_sequence, env)
            Firehose.logger.debug "HTTP GET with last_sequence #{last_sequence} for path #{path} with query #{env["QUERY_STRING"].inspect}"
          end

          def handle_request(request, env)
            # Get the Last Message Sequence from the query string.
            # Ideally we'd use an HTTP header, but android devices don't let us
            # set any HTTP headers for CORS requests.
            params = request.params
            last_sequence = params.delete('last_message_sequence').to_i
            channel       = request.path

            Firehose::Server.metrics.channel_subscribed!(channel)

            log_request   channel, last_sequence, env
            respond_async channel, last_sequence, params, env
          end
        end

        class MultiplexingHandler < Handler
          def wrap_frame(channel, message)
            JSON.generate channel: channel,
                          message: message.payload,
                          last_sequence: message.sequence
          end

          def log_request(request, subscriptions, env)
            if request.post?
              Firehose.logger.debug "HTTP multiplexing POST, subscribing #{subscriptions.inspect}"
            else
              Firehose.logger.debug "HTTP multiplexing GET with query #{env["QUERY_STRING"].inspect}"
            end
          end

          def handle_request(request, env)
            subscriptions = Consumer.multiplex_subscriptions(request)
            if subscriptions.empty?
              Firehose::Server.metrics.error!(:http_subscribe_multiplexed_empty)
              Firehose.logger.warn "Client tried to subscribe multiplexed via HTTP without any channel subscriptions."
              async_callback env,
                             400,
                             JSON.generate(error: "Subscription failed",
                                           reason: "No subscription data given - can't subscribe to nothing")
            else
              log_request request, subscriptions, env
              channels = subscriptions.map{|s| s[:channel]}
              Firehose::Server.metrics.channels_subscribed_multiplexed_long_polling!(channels)
              subscriptions.each do |sub|
                respond_async(sub[:channel], sub[:last_message_sequence] || sub[:message_sequence], sub[:params], env)
              end
            end
          end
        end
      end
    end
  end
end
