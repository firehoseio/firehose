require "json"
require "em_alldone"

module Firehose
  module Rack
    class BatchPublisher
      include Firehose::Rack::Helpers

      def call(env)
        req     = env['parsed_request'] ||= ::Rack::Request.new(env)
        method  = req.request_method

        if method == 'POST'
          EM.next_tick do
            # Both Rainbows and Thin buffer `env["rack.input"]` so we're
            # assuming that calling `read` in it is not blocking I/O.
            # However, if the body is quite large, Rainbows/Thin, may have
            # buffered it to disk, not memory, in which case this may be
            # blocking.
            # For Thin, the threshold seems to be 112Kb.
            # Also note, when Thin buffers to a file, it does so in a
            # _blocking_ way. See: https://github.com/macournoyer/thin/blob/c23f0ace66279a30d7d8d8d727d9311cb34dc89a/lib/thin/request.rb#L158
            body = env['rack.input'].read
            Firehose.logger.debug "HTTP batch published #{body.inspect}"

            begin
              # Ideally we'd stream the body without blocking and parse the
              # JSON stream. However, that isn't supported by Rainbows::EventMachine.
              batch = JSON.parse(body)
            rescue JSON::ParserError
              env['async.callback'].call response(400, "Request body was not valid JSON", "Content-Type" => "text/plain")
            else
              process_batch(batch) do |results, any_errors|
                status = if any_errors
                  500
                else
                  200
                end

                env['async.callback'].call response(status, results.to_json, "Content-Type" => "application/json")
              end
            end
          end

          # Tell the web server that this will be an async response.
          ASYNC_RESPONSE
        else
          Firehose.logger.debug "HTTP #{method} not supported"
          msg = "#{method} not supported."
          [405, {'Content-Type' => 'text/plain', 'Content-Length' => msg.size.to_s}, [msg]]
        end
      end

      private
      def publisher
        @publisher ||= Firehose::Server::Publisher.new
      end


      def process_batch(batch, &block)
        results = {}
        any_errors = false
        deferrables = []

        batch.each do |path, data|
          ttl = data["ttl"]
          results[path] = {
            "success" => 0,
            "error" => 0
          }
          data["messages"].each do |msg|
            # TODO: It is probably more efficient to write to Redis in a
            #       single batch.
            deferrables << publisher.publish(path, msg, :ttl => ttl).callback do
              results[path]["success"] += 1
            end.errback do |e|
              any_errors = true
              results[path]["error"] += 1
              Firehose.logger.debug "Error publishing: #{e.inspect}"
            end
          end
        end

        EmAlldone.with(deferrables, results, any_errors, &block)
      end
    end
  end
end
