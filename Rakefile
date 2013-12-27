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


namespace :travis do
  desc 'Prepares evergreen and JS files for Travis CI'
  task :prepare do
    # Prepare directories
    sh "mkdir -p public/javascripts/vendor"

    # Precompile coffeescript
    sh "bundle exec coffee -c -o public/javascripts lib/assets/javascripts"

    # Remove double extensions caused by sprockets naming convention
    Dir.glob 'public/javascripts/**/*.js.js' do |js_file|
      new_name = js_file.gsub '.js.js', '.js'
      sh "mv #{js_file} #{new_name}"
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
