# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "push/version"

Gem::Specification.new do |s|
  s.name        = "push"
  s.version     = Push::VERSION
  s.authors     = ["Brad Gessler"]
  s.email       = ["brad@bradgessler.com"]
  s.homepage    = ""
  s.summary     = %q{Build realtime Ruby web applications}
  s.description = %q{Push is a realtime web application toolkit for building realtime Ruby web applications.}

  s.rubyforge_project = "push"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "guard-bundler"
  s.add_development_dependency "amqp"
  s.add_development_dependency "bunny"
  s.add_runtime_dependency "rack", ">= 1.1.0"
  s.add_runtime_dependency "uuid"
  s.add_runtime_dependency "async_sinatra"
end