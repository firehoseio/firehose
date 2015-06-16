require "json"

# Version and Codename are now stored in package.json for NPM.
module Firehose
  def self.package
    filename = File.expand_path("../../../package.json", __FILE__)
    json = File.read(filename)
    JSON.parse(json)
  end

  VERSION  = self.package["version"]
  CODENAME = self.package["codename"]
end