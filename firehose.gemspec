# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "firehose/version"

Gem::Specification.new do |s|
  s.name        = "firehose"
  s.version     = Firehose::VERSION
  s.authors     = ["Brad Gessler", "Steel Fu"]
  s.email       = ["brad@polleverywhere.com", "steel@polleverywhere.com"]
  s.homepage    = "http://github.com/polleverywhere/firehose"
  s.summary     = %q{Build realtime Ruby web applications}
  s.description = %q{Firehose is a realtime web application toolkit for building realtime Ruby web applications.}

  s.rubyforge_project = "firehose"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
#  s.add_runtime_dependency "goliath", "=> 0.9.4"
  s.add_runtime_dependency "eventmachine", ">= 1.0.0.beta"
  s.add_runtime_dependency "amqp", ">= 0.9.4"
  s.add_runtime_dependency "thin"
  s.add_runtime_dependency "websocket-rack"

  s.add_development_dependency "rspec"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "guard-bundler"
  s.add_development_dependency "thin"
  # em-http dropped support for WS as of version 1.0+ (https://github.com/igrigorik/em-http-request/issues/164)
  s.add_development_dependency "em-http-request", "~> 0.3.0" 
  s.add_development_dependency "guard-coffeescript"
end