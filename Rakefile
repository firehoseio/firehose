require "rake/testtask"
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'coffee-script'


task :default => [:spec]
task :debug => ["spec:debug"]
task :ci => ["spec:ci"]

desc "Run specs with Karma runner"
task :spec => ["spec:run"]
namespace :spec do
  task :setup do
    sh %[npm install]
  end

  desc "CI specs run on PhantomJS"
  task :ci => :setup do
    sh %[./node_modules/karma/bin/karma start karma.config.coffee --browsers PhantomJS --single-run --reporters dots,junit]
  end

  desc "Run local specs in PhantomJS"
  task :run => :setup do
    sh %[./node_modules/karma/bin/karma start karma.config.coffee --browsers PhantomJS --single-run]
  end

  desc "Run local specs in Chrome and leaves the window open for debugging"
  task :debug => :setup do
    sh %[./node_modules/karma/bin/karma start karma.config.coffee --browsers Chrome]
  end
end