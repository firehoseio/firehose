require 'uri'

module Firehose
  module Default
    URI = URI.parse("//127.0.0.1:7474").freeze
  end
end