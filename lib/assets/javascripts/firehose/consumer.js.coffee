class Firehose.Consumer
  constructor: (@config = {}) ->
    # Empty handler for messages.
    @config.message      ||= ->
    # Empty handler for error handling.
    @config.error        ||= ->
    # Empty handler for when we establish a connection.
    @config.connected    ||= ->
    # Empty handler for when we're disconnected.
    @config.disconnected ||= ->
    # The initial connection failed. This is probably triggered when a
    # transport, like WebSockets is supported by the browser, but for whatever
    # reason it can't connect (probably a firewall)
    @config.failed       ||= ->
      throw "Could not connect"
    # Params that we'll tack on to the URL.
    @config.params       ||= {}
    # Do stuff before we send the message into config.message. The sensible
    # default on the webs is to parse JSON.
    @config.parse        ||= JSON.parse
    # Make sure we return ourself out of the constructor so we can chain.
    this

  connect: (delay=0) =>
    promise = _connectPromise()

    @config.connectionVerified = @_upgradeTransport
    if Firehose.WebSocket.supported()
      @upgradeTimeout = setTimeout =>
        ws = new Firehose.WebSocket @config
        ws.connect delay
      , 500
    @transport = new Firehose.LongPoll @config
    @transport.connect delay

    promise

  stop: =>
    if @upgradeTimeout?
      clearTimeout @upgradeTimeout
      @upgradeTimeout = null
    @transport.stop()
    return

  _upgradeTransport: (ws) =>
    @transport.stop()
    ws.sendStartingMessageSequence @transport.getLastMessageSequence()
    @transport = ws
    return

  # Return a promise that will succeed/fail depending on whether or not the
  # initial connection succeeds.
  _connectPromise: =>
    deferred = $.Deferred()

    origConnected = @config.connected
    @config.connected = ->
      deferred.resolve()
      if origConnected
        @config.connected = origConnected
        origConnected()

    origdisconnected = @config.disconnected
    @config.disconnected = ->
      deferred.reject()
      if origDisconnected
        @config.disconnected = origDisconnected
        origDisconnected()

    deferred.promise()
