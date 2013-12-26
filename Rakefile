require "rake/testtask"
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task :default => [:spec, 'evergreen:run']

desc 'run Rspec specs'
task :spec do
  sh 'rspec spec'
end


namespace :evergreen do
  desc 'run Evergreen specs'
  task :run do
    sh 'evergreen run'
  end

  desc 'start an Evergreen server'
  task :serve do
    sh 'evergreen serve'
  end
end
