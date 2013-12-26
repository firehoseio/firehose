guard 'bundler' do
  watch 'Gemfile'
  watch /^.+\.gemspec/
end


guard 'coffeescript',
  input: 'lib/assets/javascripts',
  output: 'public/javascripts',
  all_on_start: true


guard 'rspec', :version => 2 do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }
end


guard :copy,
  from:         'lib/assets/javascripts/vendor',
  to:           'public/javascripts/vendor',
  mkpath:       true,
  run_at_start: true
