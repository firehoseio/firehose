require "rake/testtask"
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'coffee-script'


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


namespace :travis do
  desc 'Prepares evergreen and JS files for Travis CI'
  task :prepare do
    # Prepare directories
    sh "mkdir -p public/javascripts/vendor"
    sh "mkdir -p public/javascripts/firehose"

    # Precompile coffeescript
    Dir.glob 'lib/assets/javascripts/**/*.js.coffee' do |coffee_file|
      dest = coffee_file.gsub( 'lib/assets/', 'public/' ).gsub '.js.coffee', '.js'

      File.open dest, 'w' do |file|
        file.write ::CoffeeScript.compile File.read coffee_file
      end
    end

    # Copy JS vendor files into public
    Dir.glob 'lib/assets/javascripts/vendor/*.js' do |js_file|
      sh "cp #{js_file} public/javascripts/vendor"
    end

    Dir.glob 'spec/javascripts/support/*.js' do |js_file|
      sh "cp #{js_file} public/javascripts/vendor"
    end
  end
end
