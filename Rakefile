require "rake/testtask"
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task :default => [:spec]

desc 'run Rspec specs'
task :spec do
  sh 'rspec spec'
end