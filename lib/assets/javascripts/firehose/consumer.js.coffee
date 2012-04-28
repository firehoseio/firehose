class Firehose.Consumer
  # Transports that are available to Firehose.
  @transports: [Firehose.WebSocket, Firehose.LongPoll]

  # Generate a random consumer id.
  @nextConsumerId: ->
    Math.floor((Math.random()*99999999999)+1)

  constructor: (config = {}) ->
    # The consumerId is used by the server to remember messages between requests. In a production environment,
    # this should probably be some combination of "user_id-rand". Why the rand? Because a user may have multiple
    # tabs open to the application, and each tab needs a different channel on the server.
    config.consumerId   ||= Firehose.Consumer.nextConsumerId()
    # List of transport stragies we have to use.
    config.transports   ||= Firehose.Consumer.transports
    # Empty handler for messages.
    config.message      ||= ->
    # Empty handler for error handling.
    config.error        ||= ->
    # Empty handler for when we establish a connection.
    config.connected    ||= ->
    # Empty handler for when we're disconnected.
    config.disconnected ||= ->
    # The initial connection failed. This is probably triggered when a transport, like WebSockets
    # is supported by the browser, but for whatever reason it can't connect (probably a firewall)
    config.failed       ||= ->
      throw "Could not connect"
    # URL that we'll connect to.
    config.uri          ||= undefined
    # Params that we'll tack on to the URL. We include a consumerId in here for kicks.
    config.params       ||= { cid: config.consumerId }
    # Do stuff before we send the message into config.message. The sensible
    # default on the webs is to parse JSON.
    config.parse ||= (body) ->
      $.parseJSON(body)

    # Hang on to these config for when we connect.
    @config = config
    # Make sure we return ourself out of the constructor so we can chain.
    this

  connect: =>
    # Get a list of transports that the browser supports
    supportedTransports = (transport for transport in @config.transports when transport.supported())
    # Mmmkay, we've got transports supported by the browser, now lets try connecting 
    # to them and dealing with failed connections that might be caused by firewalls,
    # or other network connectivity issues.
    transports = for transport in supportedTransports
      # Copy the config so we can modify it with a failed callback.
      config = @config
      # Map the next transport into the existing transports connectionError
      # If the connection fails, try the next transport supported by the browser.
      config.failed = =>
        # Map the next transport to connect insie of the current transport failures
        if nextTransport = supportedTransports.pop()
          new nextTransport(config).connect()
        else
          @config.failed() # Call the original fail method passed into the Firehose.Consumer
      new transport(config)
    # Fire off the first connection attempt.
    transports[0].connect()