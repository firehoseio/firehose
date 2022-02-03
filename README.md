      __ _          _
     / _(_)        | |
    | |_ _ _ __ ___| |__   ___  ___  ___
    |  _| | '__/ _ \ '_ \ / _ \/ __|/ _ \
    | | | | | |  __/ | | | (_) \__ \  __/
    |_| |_|_|  \___|_| |_|\___/|___/\___|

    Build realtime web applications in Ruby and JS

[![Build Status](https://travis-ci.org/firehoseio/firehose.svg?branch=master)](https://travis-ci.org/firehoseio/firehose) [![Code Climate](https://codeclimate.com/github/firehoseio/firehose/badges/gpa.svg)](https://codeclimate.com/github/firehoseio/firehose) [![Test Coverage](https://codeclimate.com/github/firehoseio/firehose/badges/coverage.svg)](https://codeclimate.com/github/firehoseio/firehose/coverage)

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

or

```
docker-compose build
docker-compose up
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

## Run the tests

```sh
docker-compose run firehose bundle exec rspec spec
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

There's also a Consumer that uses channel multiplexing.
The multiplexed consumer is useful for scenarios where you want to subscribe
to messages from many channels at once, without having to use one connection
per channel. You can specify a list of channels to subscribe to, including a
handler function per channel that gets called with all messages coming from that
channel.

Example:

```javascript
new Firehose.MultiplexedConsumer({
  connected: function(){
    console.log("Great Scotts!! We're connected!");
  },
  disconnected: function(){
    console.log("Well shucks, we're not connected anymore");
  },
  error: function(){
    console.log("Well then, something went horribly wrong.");
  },
  // Note that we don't specify a general message handler function
  // but instead define one per channel below

  // Note that we do NOT specify a protocol here because we don't
  // know that yet. We also don't specify a specific channel name as part of
  // the URI but instead pass in a list of subscriptions below
  uri: '//localhost:7474/',

  // List of channel subscriptions:
  channels: {
    "/my/channel/1": {
      last_sequence: 10,        // defaults to 0 and can be ommitted
      message: function(msg) {
        console.log("got message on channel 1:");
        console.log(msg);
      }
    },
    "/my/channel/2": {
      message: function(msg) {
        console.log("got message on channel 2:");
        console.log(msg);
      }
    }
  }
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

## Publishing Options
You can pass additional options to the publisher that set specific custom
configuration http headers. The options available are:
- TTL (how long should the message be buffered for)
- Buffer size (how many messages for the channel should be kept in the buffer)
- Deprecated (if marked as deprecated, any publications or subscriptions to the channel will be logged with a deprecation warning)
- Persist (persisting causes the channel & message to not be expired after a given or the default TTL)

The corresponding HTTP headers and allowed values are:
- `Cache-Control: int`
- `X-Firehose-Buffer-Size: int`
- `X-Firehose-Deprecated: true | false`
- `X-Firehose-Persist: true | false`

```ruby
firehose = Firehose::Client::Producer::Http.new('//127.0.0.1:7474')
# mark channel as deprecated
firehose.publish(json).to("/my/messages/path", deprecated: true)
# expire after 120 seconds
firehose.publish(json).to("/my/messages/path", ttl: 120)
# only keep last item
firehose.publish(json).to("/my/messages/path", buffer_size: 1)
# persist channel & message forever (or until a new message for this channel declares a new TTL and persist != true)
firehose.publish(json).to("/my/messages/path", persist: true)
```

These options can be of course be combined within a single request.

# Configuration

Firehose can be configured via environmental variables. Take a look at the [`.env.sample`](./.env.sample) file for more info.

## Server Configuration

The Firehose server may be configured via the `Firehose::Server.configuration` object as follows:

```ruby
require "firehose"

# Implement a custom message handler.
class MyFilter < Firehose::Server::MessageFilter
  def process(message)
    # SHOUT AT ALL THE SUBSCRIBERS!
    name = params["name"]
    message.payload = "HEY #{name}!, #{message.payload.upcase}!"
  end
end

Firehose::Server.configuration do |config|
  # Custom message filter. This is useful if you want to implement
  # authorization per-message for Firehose.
  config.message_filter = MyFilter

  # Configure redis connection.
  config.redis.url = ENV.fetch "FIREHOSE_REDIS_URL", "redis://redis:6379/10"
end
```

## Custom MessageFilters

As mentioned above you can define custom MessageFilters which allow you to
add custom logic for things like authentication & filtering of content.
By default, the `Firehose::Server::MessageFilter` base class is used, which does
nothing to the messages being published.
You can override the following methods in your own implementations:

```ruby
class MyFilter < Firehose::Server::MessageFilter
  # Optional override if you need to do any other setup operation.
  # Make sure to call super(channel).
  # - channel: name of the channel (String)
  def initialize(channel)
    super(channel)
    MyLogger.info "Subscribing to channel: #{channel}"
  end

  # Optional, called once before process().
  # - params: Hash of params of the subscription message the client sent
  def on_subscribe(params)
    @my_param = params["my-param"].to_i

    # You can also optionally raise an instance of
    # Firehose::Server::ChannelSubscription::Failed
    # this will cause the client to receive an error message of the form:
    # { error: "Subscription failed", reason: error_reason }
    # and the client will call its `subscriptionFailed` callback (if configured)
  end

  # Custom logic for a message to be published to client.
  # - message: Firehose::Server::Message instance
  def process(message)
    if @my_param > 10
      message.payload += "My-Param: #{@my_param}"
    end
  end

  # optional cleanup logic
  def on_unsubscribe
  end
end
```

## Deprecation logging for channels

## Client publishing option
You can mark a message as deprecated (to be logged by Firehose) by passing
`deprecated: true` as an option to `Firehose::Client::Producer::HTTP#put`.

```ruby
firehose = Firehose::Client::Producer::Http.new('//127.0.0.1:7474')
firehose.publish("{'hello': 'world'}").to("/my/messages/path", deprecated: true)
```

## Server side config
You can specify a list of channels that are marked as deprecated and will cause subscription and publish events on any of those channels to be logged with a special deprecation message.

Example config:

```ruby
Firehose::Server.configuration do |config|
  # set a static list of deprecated channels:
  config.deprecated_channels = ["/foo/bar.json", "/foo/bar/baz.json"]
  # provide a block to determine if a channel is deprecated via custom logic:
  config.deprecated_channel do |channel|
    channel =~ /^\/foo\/*\.json$/
  end
end
```

## Rack Configuration

There are two rack applications that are included with Firehose: `Firehose::Rack::Producer` which a client can `PUT` HTTP request with message payloads to publish information on Firehose and the `Firehose::Rack::Consumer` application which a client connects to via HTTP long polling or WebSockets to consume a message.

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

### Not using sprockets?

If you don't intend to use the Firehose JavaScript client in a Ruby stack where Sprockets is available, you can grab the unminified source by running:

```sh
$ firehose javascript > firehose.js
```

Copy the firehose.js where needed in your project.

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

The recommended method of deploying Firehose is to deploy it separately from your main app.

1. Create a new project with a Gemfile such as

```
gem "firehose"
gem "airbrake"
gem "rainbows",   :require => false
gem "rack", "~> 1.4.0" # if you're using Rainbows. See https://github.com/firehoseio/firehose/commit/dfe55fff
gem "foreman",    :require => false
gem "capistrano", :require => false
```

Of course, you could use `exceptional` instead of `airbrake` and `thin` instead of `rainbows`.

2. Set up `config/deploy.rb` to your liking. You can follow most directions for using Capistrano and Foreman to deploy Rack apps, such as https://gist.github.com/1027117

3. Set up `config/rainbows.rb` (if you are using Rainbows!). The gem includes example configurations scripts to get you started. There's also an example at https://gist.github.com/bradgessler/f2416efdbb1771e983b3.

# New releases & version bump

For a new release of Firehose, bump the version number in `lib/firehose/version.rb` as well as `package.json`.
Make sure, they have the same version number.

# Support

## Ruby version

Firehose will support the latest minor 2.x revisions of Ruby that are officially supported by the Ruby community. More details at https://www.ruby-lang.org/.
