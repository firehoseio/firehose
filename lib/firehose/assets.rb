require 'sprockets'

module Firehose
  # Deal with bundling Sprocket assets into environments (like Rails or Sprockets)
  module Assets
    def self.path(*segs)
      File.join File.expand_path('../../assets', __FILE__), segs
    end

    # Integrate Firehose ./lib/assets files into a sprocket-enabled environment.
    module Sprockets
      # Entry-point Javascript for Sprockets project.
      JAVASCRIPT = "firehose.js"

      # Drop flash and javascript paths to Firehose assets into a sprockets environment.
      def self.configure(env)
        env.append_path Firehose::Assets.path('javascripts')
        env
      end

      # The "main" javascript that folks should compile and use in their
      # web applications.
      def self.javascript
        Firehose::Assets::Sprockets.environment[JAVASCRIPT].source
      end

      # Return a new sprockets environment configured with Firehose.
      def self.environment
        configure ::Sprockets::Environment.new
      end

      # Quick and dirty way for folks to compile the Firehose assets to a path
      # from the CLI and use. These are usualy non-ruby (or non-sprockets) folks
      # who want to run the firehose process and use the JS in a web app.
      def self.manifest(directory)
        ::Sprockets::Manifest.new(environment, directory)
      end

      # Try to automatically configure Sprockets if it's detected in the project.
      def self.auto_detect
        if defined? ::Sprockets and ::Sprockets.respond_to? :append_path
          Firehose::Assets::Sprockets.configure ::Sprockets
        end
      end

      def self.manifest_paths
        paths = []
        paths << File.basename(Firehose::Assets.path('/javascripts/firehose/firehose.js.coffee'), '.coffee')
        paths
      end
    end
  end
end

# Detect if Sprockets is loaded. If it is, lets configure Firehose to use it!
Firehose::Assets::Sprockets.auto_detect
