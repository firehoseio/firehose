require 'push/version'

require 'amqp'

module Push
  autoload :Subscription, 'push/subscription'
  autoload :Publisher,    'push/publisher'
  autoload :Goliath,      'push/goliath'
end