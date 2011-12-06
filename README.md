                    /
     ___       ___ (___
    |   )|   )|___ |   )
    |__/ |__/  __/ |  /
    |
    
    A Realtime Ruby web application toolkit

# What is Push?

Push is both a Rack application and Javascript that makes building scalable real-time web applications possible.

# How is it different from socket.io?

socket.io attempts to store connection state per node instance. Push makes no attempt to store connection state.

Also, socket.io attempts to abstract a low-latency full duplex port. Push assumes that its impposible to simulate this in older web browsers that don't support WebSockets. As such, Push focuses on low-latency server-to-client connections and encourages the use of HTTP transports for client-to-server communications.

Finally, push attempts to solve data consistency issues and authentication by encourage the use of proxying to the web application.

# Getting Started

First, you'll need to install RabbitMQ. In the future, Push may support multiple backends, but for now we use RabbitMQ. Fire up that daemon and we'll setup the server.

## The Consumer

The consumer is the web server that your client connects to for real-time updates. Create a config.ru file with the following:

```ruby
require 'rubygems'
require 'push'

run Push::Transport::Dispatcher {|config|
  # Extract the consumer ID from the HTTP session. This could be a cookie
  # query param, or whatever.
  config.consumer {|env|
    Push::Consumer.new(env['HTTP_CONSUMER_ID'])
  }
  # Use the /url/path for the queue channel. You could change this to a query
  # param, or whatever
  config.channel {|env|
    env['PATH_INFO']
  }
}
```

Now run the config.ru file in a server that supports async Rack callbacks (like thin or rainbows)

```ruby
thin -R config.ru -p 4000 start
```

## The Producer

Lets test the producer! Open two terminal windows. In one window, curl the consumer server:

```sh
curl "http://localhost:4000/"
```

Then run the following script in another terminal:

```ruby
require 'rubygems'
require 'push'

Push::Producer.new.publish('hi there!').to('/greetings')
```

Viola! The curl script will return 'hi there!'

Now you're on your way to building realtime web applications.