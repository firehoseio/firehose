                    /
     ___       ___ (___
    |   )|   )|___ |   )
    |__/ |__/  __/ |  /
    |
    
    A Realtime Ruby web application toolkit

# What is Push?

Push is both a Rack application and JavasSript library that makes building scalable real-time web applications possible.

# How is it different from socket.io?

socket.io attempts to store connection state per node instance. Push makes no attempt to store connection state.

Also, socket.io attempts to abstract a low-latency full-duplex port. Push assumes that its impossible to simulate this in older web browsers that don't support WebSockets. As such, Push focuses on low-latency server-to-client connections and encourages the use of HTTP transports for client-to-server communications.

Finally, push attempts to solve data consistency issues and authentication by encourage the use of proxying to the web application.

# Getting Started

First, you'll need to install and run RabbitMQ.

```
apt-get install rabbitmq    # Install on Ubuntu
brew install rabbitmq       # Install on Mac Homebrew
```

## The Consumer

The consumer is the web server that your client connects to for real-time updates. Create a config.ru file with the following:

```ruby
require 'rubygems'
require 'push'

run Push::Transport::Dispatcher.new do |config|
  config.timeout = 20
  
  # Extract the consumer ID from the HTTP session. This could be a cookie
  # query param, or whatever.
  config.consumer = Proc.new do |env|
    Push::Consumer.new(env['HTTP_CONSUMER_ID'])
  end
  
  # Use the /url/path for the queue channel. You could change this to a query
  # param, or whatever
  config.channel = Proc.new do |env|
    env['PATH_INFO']
  end
end
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

## JavaScript Client

Then in your browser create a new Push Client object as such:

```javascript
new Push.Client()
  .url({
    websocket: 'ws://some_websocket_url.com',
    longpoll:  'http://some_longpoll_url.com'
  })
  .params({
    cid: '024023948234'
  })
  .options({
    timeout: 5000
  })
  .message(function(msg){
    alert(msg); // Fires when a message is received from the server.
  })
  .connected(function(){
    alert('Howdy friend!');
  })
  .disconnected(function(){
    alert('Bu bye');
  })
  .connect()
```