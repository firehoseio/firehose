require "thread"

module Firehose
  module Client
    module Producer
      class Http
        class Async
          def initialize(producer)
            @queue = Queue.new
            @worker_mutex = Mutex.new
            @worker = Worker.new @queue, producer

            at_exit { @worker_thread && @worker_thread[:should_exit] = true }
          end

          # Although the options here are specified for each message, they can
          # actually be more global. Specifically:
          # * :timeout is global. The most recently specified timeout will be
          #   used.
          # * :ttl is per channel. The most recently specified ttl for a given
          #   channel will be used.
          def enqueue(message, channel, opts, &block)
            ensure_worker_running
            @queue << [message, channel, opts, block]
          end

          private

          def ensure_worker_running
            return if worker_running?
            @worker_mutex.synchronize do
              return if worker_running?
              @worker_thread = Thread.new do
                @worker.run
              end
            end
          end

          def worker_running?
            @worker_thread && @worker_thread.alive?
          end


          class Worker
            def initialize(queue, producer)
              @queue = queue
              @batch = []
              @callbacks = []
              @lock = Mutex.new
              @producer = producer
            end

            def run
              until Thread.current[:should_exit]
                return if @queue.empty?

                @lock.synchronize do
                  until @queue.empty?
                    @batch << @queue.pop
                  end
                end


                @producer.batch_publish(batch_data, :timeout => @timeout) do |response|
                  @callbacks.each do |callback|
                    callback.call response
                  end

                  @lock.synchronize do
                    @batch.clear
                    @callbacks.clear
                  end
                end
              end
            end

            def is_requesting?
              @lock.synchronize { !@batch.empty? }
            end

            private

            def batch_data
              hash = {}
              # We're mutating instance variables, so we need a lock to be safe.
              @lock.synchronize do
                @batch.each do |message, channel, opts, block|
                  @timeout = opts[:timeout] if opts[:timeout] # Most recent overwrites globally.
                  hash[channel] ||= {:messages => []}
                  hash[channel][:messages] << message
                  hash[channel][:ttl] = opts[:ttl] if opts[:ttl] # Most recent overwrites for each channel.
                  @callbacks << block if block
                  # TODO: Maybe we don't actually need to support blocks.
                end
              end
              hash
            end
          end
        end
      end
    end
  end
end
