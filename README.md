      __ _          _                    
     / _(_)        | |                   
    | |_ _ _ __ ___| |__   ___  ___  ___ 
    |  _| | '__/ _ \ '_ \ / _ \/ __|/ _ \
    | | | | | |  __/ | | | (_) \__ \  __/
    |_| |_|_|  \___|_| |_|\___/|___/\___|
    
    Build realtime web applications in Ruby and JS

[![Build Status](https://travis-ci.org/polleverywhere/firehose.png)](https://travis-ci.org/polleverywhere/firehose)

# What is Firehose?

Firehose is both a Rack application and JavaScript library that makes building real-time web applications possible.

# Getting Started

First, you'll need to [install and run Redis 2.6](http://redis.io/download).
Version 2.6 is required because Firehose uses [Lua/EVAL](http://redis.io/commands/eval) for its transactions, which is not available in earlier versions of Redis.

Then install the gem.

```sh
$ gem install firehose
```

## The Server

Now fire up the server.

```
$ firehose server
>> Thin web server (v1.3.1 codename Triple Espresso)
>> Maximum connections set to 1024
>> Listening on 127.0.0.1:7474, CTRL+C to stop
```

In case you're wondering, the Firehose application server runs the Rack app `Firehose::Rack::App.new` inside of Thin or Rainbows! `Firehose::Rack::App` consists of a bunch of smaller apps and a middleware, which is useful for hacking.

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

# The JavaScript Consumer

Firehose doesn't just stop at curl; it has a full-featured JavaScript client that lets you subscribe to channels for live updates.

Still have the server running? Copy and paste the code below into Firebug or the WebKit console.

```javascript

new Firehose.Consumer({
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
  uri: '//localhost:7474/hello'
}).connect();
```

Then publish another message.

```sh
$ curl -X PUT -d "\"This is almost magical\"" "http://localhost:7474/hello"
```

# How is it different from socket.io?

socket.io attempts to store connection state per node instance. Firehose makes no attempt to store connection state.

Also, socket.io attempts to abstract a low-latency full-duplex port. Firehose assumes that its impossible to simulate this in older web browsers that don't support WebSockets. As such, Firehose focuses on low-latency server-to-client connections and encourages the use of existing HTTP transports, like POST and PUT, for client-to-server communications.

# The Ruby Publisher

While you can certainly make your own PUT requests when publishing messages, Firehose includes a Ruby client for easy publishing.

```ruby
require 'firehose'
require 'json'
json = {'hello'=> 'world'}.to_json
firehose = Firehose::Client::Producer::Http.new('//127.0.0.1:7474')
firehose.publish(json).to("/my/messages/path")
```

# Configuration

Firehose can be configured via environmental variables. Take a look at the [`.env.sample`](./.env.sample) file for more info.

## Rack Configuration

There are two rack applications that are included with Firehose: `Firehose::Rack::Producer` which a client can `PUT` HTTP request with message payloads to publish information on Firehose and the `Firehose::Rack::Consumer` application which a client connects to via HTT long polling or WebSockets to consume a message.

### Consumer Configuration

```ruby
# Kitchen-sink rack configuration file example
require 'firehose'

consumer = Firehose::Rack::Consumer.new do |app|
  # Configure how long the server should wait before send the client a 204
  # with a request to reconnect. Typically browsers time-out the client connection
  # after 30 seconds, so we set the `Firehose.Consumer` JS client to 25, and the
  # server to 20 to make sure latency or timing doesn't cause any problems.
  app.http_long_poll.timeout = 20
end

run consumer
```

### Publisher Configuration

```ruby
# Kitchen-sink rack configuration file example
require 'firehose'

# There's nothing to configure with the Publisher, but its possible that
# you might include rack middleware authorization mechanisms here to control
# who can publish to Firehose.

run Firehose::Rack::Publisher.new
```

## Sprockets

Using Sprockets is the recommended method of including the included client-side assets in a web page.

1. Add the firehose gem in your app's Gemfile.

2. Append the firehose gem's assets to the sprockets path. In a Rails app, this is usually done in an initializer.

```ruby
# Add firehose to a custom sprockets configuration.
my_sprockets_env = Sprockets::Environment.new
Firehose::Assets::Sprockets.configure my_sprockets_env
```

3. Require your config file and the firehose gem. This would look something like this:

```ruby
#= require some/other/js/file
#= require lib/firehose_config
#= require firehose
#= require some/more/js/files
```

It is important that your firehose config file comes first.

# Web Server

Firehose currently supports Thin and Rainbows! (which is the default). Neither is listed as a dependency in the gemspec so that you don't need to install whichever one you aren't using. You can set which server to use via the `.env` file (recommended) or with the `-s` option to `bin/firehose`.

# Exception Notification

If you'd like to be notified of exceptions, add something like this in your custom config.ru file.

```ruby
# Use exceptional to handle anything missed by Rack::Exceptional
if exceptional_key = ENV['EXCEPTIONAL_KEY']
  require 'exceptional'
  EM.error_handler do |e|
    Firehose.logger.error "Unhandled exception: #{e.class} #{e.message}\n#{e.backtrace.join "\n"}"
    ::Exceptional.handle(e)
  end
end
```

# Deployment

The recommended method of deploying firehose is to deploy it separately from your main app.

1. Create a new project with a Gemfile such as

```
gem "firehose"
gem "airbrake"
gem "rainbows",   :require => false
gem "foreman",    :require => false
gem "capistrano", :require => false
```

Of course, you could use `exceptional` instead of `airbrake` and `thin` instead of `rainbows`.

2. Set up `config/deploy.rb` to your liking. You can follow most directions for using Capistrano and Foreman to deploy Rack apps, such as https://gist.github.com/1027117

3. Set up `config/rainbows.rb` (if you are using Rainbows!). The gem includes an example to get you started.
