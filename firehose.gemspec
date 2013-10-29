# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "firehose/version"

Gem::Specification.new do |s|
  s.name        = "firehose"
  s.version     = Firehose::VERSION
  s.authors     = ["Brad Gessler", "Steel Fu", "Paul Cortens", "Zach Zolton"]
  s.email       = ["brad@polleverywhere.com", "steel@polleverywhere.com", "paul@polleverywhere.com", "zach@polleverywhere.com"]
  s.homepage    = "http://firehose.io/"
  s.summary     = %q{Build realtime Ruby web applications}
  s.description = %q{Firehose is a realtime web application toolkit for building realtime Ruby web applications.}

  s.rubyforge_project = "firehose"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_runtime_dependency "eventmachine", ">= 1.0.0"
  s.add_runtime_dependency "em-hiredis", ">= 0.2.0"
  s.add_runtime_dependency "thor"
  s.add_runtime_dependency "faraday"
  s.add_runtime_dependency "faye-websocket"
  s.add_runtime_dependency "em-http-request", ">= 1.0.0"
  s.add_runtime_dependency "json"

  s.add_development_dependency "rspec"
  s.add_development_dependency "webmock"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "guard-bundler"
  s.add_development_dependency "guard-coffeescript"
  s.add_development_dependency "rainbows", "~> 4.5.0"
  s.add_development_dependency "thin"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "async_rack_test"
  s.add_development_dependency "foreman"
  s.add_development_dependency "sprockets"
  s.add_development_dependency "rake"
end
