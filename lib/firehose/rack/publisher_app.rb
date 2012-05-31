module Firehose
  module Rack
    class PublisherApp
      def call(env)
        req     = env['parsed_request'] ||= ::Rack::Request.new(env)
        path    = req.path
        method  = req.request_method

        if method == 'PUT'
          body = env['rack.input'].read
          Firehose.logger.debug "HTTP published `#{body}` to `#{path}`"
          publisher.publish(path, body)

          [202, {'Content-Type' => 'text/plain', 'Content-Length' => '0'}, []]
        else
          Firehose.logger.debug "HTTP #{method} not supported"
          msg = "#{method} not supported."
          [501, {'Content-Type' => 'text/plain', 'Content-Length' => msg.size.to_s}, [msg]]
        end
      end


      private
      def publisher
        @publisher ||= Firehose::Publisher.new
      end
    end
  end
end
