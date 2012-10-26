class Firehose.Consumer
  constructor: (config = {}) ->
    # Empty handler for messages.
    config.message      ||= ->
    # Empty handler for error handling.
    config.error        ||= ->
    # Empty handler for when we establish a connection.
    config.connected    ||= ->
    # Empty handler for when we're disconnected.
    config.disconnected ||= ->
    # The initial connection failed. This is probably triggered when a
    # transport, like WebSockets is supported by the browser, but for whatever
    # reason it can't connect (probably a firewall)
    config.failed       ||= ->
      throw "Could not connect"
    # Params that we'll tack on to the URL.
    config.params       ||= {}
    # Do stuff before we send the message into config.message. The sensible
    # default on the webs is to parse JSON.
    config.parse        ||= JSON.parse
    # Hang on to these config for when we connect.
    @config = config
    # Make sure we return ourself out of the constructor so we can chain.
    this

  connect: (delay=0) =>
    setTimeout =>
      Firehose.WebSocket.test @config, =>
        @transport.stop()
        @config.lastMessageSequence = @transport._lastMessageSequence
        @transport = new Firehose.WebSocket @config
        @transport.connect delay
    , 1000
    @transport = new Firehose.LongPoll @config
    @transport.connect delay

  stop: =>
    @transport.stop()
