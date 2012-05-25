require 'uri'

module Firehose
  module Default
    # Default URI for the Firehose server. Consider the port "well-known" and bindable from other apps.
    URI = URI.parse("//127.0.0.1:7474").freeze
  end
end
