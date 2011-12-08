module Push
  class PushGenerator < Rails::Generator::Base
    def manifest
      record do |m|
        # Initializer
        m.directory File.join("config", "initializers")
        m.file "config/initializers/push.rb",            "config/initializers/push.rb"

        # We should compress these into 1 file
        m.directory File.join("public", "push", "javascripts")
        m.file "vendor/assets/javascripts/push/helper.js",         "public/push/javascripts/helper.js"
        m.file "vendor/assets/javascripts/push/client.js",         "public/push/javascripts/client.js"
        m.file "vendor/assets/javascripts/push/long_poll.js",      "public/push/javascripts/long_poll.js"
        m.file "vendor/assets/javascripts/push/transport.js",      "public/push/javascripts/transport.js"
        m.file "vendor/assets/javascripts/push/web_socket.js",     "public/push/javascripts/web_socket.js"

        # Flash Socket polyfill
        m.directory File.join("public", "push", "javascripts", "flash")
        m.file "vendor/assets/javascripts/push/flash/FABridge.js",        "public/push/javascripts/flash/FABridge.js"
        m.file "vendor/assets/javascripts/push/flash/swfobject.js",       "public/push/javascripts/flash/swfobject.js"
        m.file "vendor/assets/javascripts/push/flash/web_socket.js",      "public/push/javascripts/flash/web_socket.js"
        m.file "vendor/assets/WebSocketMain.swf",                         "public/push/javascripts/flash/WebSocketMain.swf"
      end
    end

    def source_root
      File.expand_path('../../../', __FILE__)
    end
  end
end
