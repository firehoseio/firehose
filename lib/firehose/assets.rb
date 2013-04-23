module Firehose
  # Deal with bundling Sprocket assets into environments (like Rails or Sprockets)
  module Assets
    def self.path(*segs)
      File.join File.expand_path('../../assets', __FILE__), segs
    end

    # Integrate Firehose ./lib/assets files into a sprocket-enabled environment.
    module Sprockets
      # Drop flash and javascript paths to Firehose assets into a sprockets environment.
      def self.configure(env)
        env.append_path Firehose::Assets.path('javascripts')
        env
      end

      # Try to automatically configure Sprockets if its detected in the project.
      def self.auto_detect
        if defined? ::Sprockets and ::Sprockets.respond_to? :append_path
          Firehose::Assets::Sprockets.configure ::Sprockets
        end
      end

      def self.manifest
        paths = []
        paths << File.basename(Firehose::Assets.path('/javascripts/firehose/firehose.js.coffee'), '.coffee')
        paths
      end
    end
  end
end
