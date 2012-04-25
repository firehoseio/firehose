      __ _          _                    
     / _(_)        | |                   
    | |_ _ _ __ ___| |__   ___  ___  ___ 
    |  _| | '__/ _ \ '_ \ / _ \/ __|/ _ \
    | | | | | |  __/ | | | (_) \__ \  __/
    |_| |_|_|  \___|_| |_|\___/|___/\___|
    
    Build Realtime web applications in Ruby

# What is Firehose?

Firehose is both a Rack application and JavasScript library that makes building scalable real-time web applications possible.

# Getting Started

First, you'll need to install and run RabbitMQ.

```sh
$ apt-get install rabbitmq    # Install on Ubuntu
$ brew install rabbitmq       # Install on Mac Homebrew
```

Then install the gem.

```sh
$ gem install firehose
```

## The Server

Now fire up the server.

```ruby
$ firehose server
>> Thin web server (v1.3.1 codename Triple Espresso)
>> Maximum connections set to 1024
>> Listening on 127.0.0.1:7478, CTRL+C to stop
```

In case you're wondering, the Firehose application server runs the Rack app `Firehose::Rack::App.new` inside of Thin.

## Publish a message to a bunch of subscribers

Lets test it out! Open two terminal windows. In one window, curl:

```sh
$ curl "http://localhost:7474/hello"
```

Then run the following in the other terminal:

```sh
$ curl -X PUT -d "Greetings fellow human being..." "http://localhost:7474/hello"
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
new Firehose.Client({
  message: function(msg){
    console.log(msg);
  },
  connected: function(){
    console.log("Great Scotts!! We're connected!");
  },
  disconnected: function(){
    console.log("Well shucks, we're not connected anymore");
  },
  error: function(){
    console.log("Well then, something went horribly wrong.");
  },
  // Note that we do NOT specify a protocol here because we don't
  // know that yet.
  uri: '//localhost:7478/hello'
}).connect();
```

Then publish another message.


```sh
$ curl -X PUT -d "This is almost magical" "http://localhost:7478/hello"
```

# How is it different from socket.io?

socket.io attempts to store connection state per node instance. Firehose makes no attempt to store connection state.

Also, socket.io attempts to abstract a low-latency full-duplex port. Firehose assumes that its impossible to simulate this in older web browsers that don't support WebSockets. As such, Firehose focuses on low-latency server-to-client connections and encourages the use of existing HTTP transports, like POST and PUT, for client-to-server communications.

Finally, Firehose attempts to solve data consistency issues and authentication by encourage the use of proxying to the web application.