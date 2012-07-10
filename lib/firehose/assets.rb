module Firehose
  # Deal with bundling Sprocket assets into environments (like Rails or Sprockets)
  module Assets
    def self.path(*segs)
      File.join File.expand_path('../../assets', __FILE__), segs
    end

    module Sprockets
      # Drop flash and javascript paths to Firehose assets into a sprockets environment.
      def self.configure(env = ::Sprockets)
        env.append_path Assets.path('flash')
        env.append_path Assets.path('javascripts')
        env
      end

      def self.auto_detect_configuration
        if defined? ::Sprockets
          Firehose::Assets::Sprockets.configure
        end
      end
    end
  end
end