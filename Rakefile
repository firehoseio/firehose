require "rake/testtask"
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task :default => :spec
task :debug => ["spec:debug"]
task :ci => ["spec:ci"]

task :spec => ["spec:all"]

namespace :spec do
  desc "Run all specs"
  task :all => [:ruby]

  desc 'run Rspec specs'
  task :ruby do
    sh 'rspec spec'
  end
end
