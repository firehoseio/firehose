      __ _          _                    
     / _(_)        | |                   
    | |_ _ _ __ ___| |__   ___  ___  ___ 
    |  _| | '__/ _ \ '_ \ / _ \/ __|/ _ \
    | | | | | |  __/ | | | (_) \__ \  __/
    |_| |_|_|  \___|_| |_|\___/|___/\___|
    
    Build Realtime web applications in Ruby

# What is Firehose?

Firehose is both a Rack application and JavasScript library that makes building scalable real-time web applications possible.

# How is it different from socket.io?

socket.io attempts to store connection state per node instance. Firehose makes no attempt to store connection state.

Also, socket.io attempts to abstract a low-latency full-duplex port. Firehose assumes that its impossible to simulate this in older web browsers that don't support WebSockets. As such, Firehose focuses on low-latency server-to-client connections and encourages the use of existing HTTP transports, like POST and PUT, for client-to-server communications.

Finally, Firehose attempts to solve data consistency issues and authentication by encourage the use of proxying to the web application.

# Getting Started

First, you'll need to install and run RabbitMQ.

```sh
apt-get install rabbitmq    # Install on Ubuntu
brew install rabbitmq       # Install on Mac Homebrew
```

Then install the gem.

```sh
gem install firehose
```

## The Server

The consumer is the web server that your client connects to for real-time updates. Create a config.ru file with the following:

```ruby
require 'rubygems'
require 'firehose'

run Firehose::Rack::App.new
```

Now run the config.ru file in a server that supports async Rack callbacks (like thin or rainbows)

```ruby
thin -R config.ru -p 4000 start
```

## Publish a message to a bunch of subscribers

Lets test it out! Open two terminal windows. In one window, curl:

```sh
curl "http://localhost:4000/hello"
```

Then run the following in the other terminal:

```sh
curl -X PUT -d "Greetings fellow human being..." "http://localhost:4000/hello"
```

and you should see the message in the other terminal.

```sh
Greetings fellow human being...
```

## Yeah, so?

You have a dirt simple HTTP pub-sub feed. You could setup an `after_commit` hook on ActiveRecord to push JSON to an end-point. On the other side, you could have a Backbone.js application that picks up the changes and updates the client-side UI.

Holy mackerel! Its a nice, clean, RESTful way to build real-time web applications.

# The JavaScript Client

Firehose doesn't just stop at curl; it has a full-featured JavaScript client that lets you subscribe to channels for live updates.

Still have the server running? Copy and paste the code below into Firebug or the WebKit console.

```javascript
new Firehose.Client()
  .url({
    websocket: 'ws://localhost:4000/hello',
    longpoll:  'http://localhost:4000/hello'
  })
  .params({
    cid: '024023948234'
  })
  .options({
    timeout: 5000
  })
  .message(function(msg){
    console.log(msg);
  })
  .connected(function(){
    console.log('Howdy friend!');
  })
  .disconnected(function(){
    console.log('Bu bye.');
  })
  .connect()
```

Then publish another message.


```sh
curl -X PUT -d "This is almost magical" "http://localhost:4000/hello"
```