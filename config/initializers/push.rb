yaml = YAML.load(File.open(File.join(File.dirname(__FILE__), %w[.. push.yml])))

# Why are we checking for Rails? Because we might boot from push.rb, which doesn't use Rails
if defined? Rails
  yaml = yaml[Rails.env]
  Push.config.logger = Rails.logger
else
  yaml = yaml[ENV['ENV'] || 'development']
end

Push.config.from_hash(yaml)

module Application
  Push = Push::Producer.new
end