class Firehose.Client
  # Transports that are available to Firehose.
  @transports: ['WebSocket', 'LongPoll']

  constructor: (config={}) ->
    # List of transport stragies we have to use.
    config.transports   ||= Firehose.Client.transports
    # Empty handler for messages.
    config.message      ||= ->
    # Empty handler for error handling.
    config.error        ||= ->
    # Empty handler for when we establish a connection.
    config.connected    ||= ->
    # Empty handler for when we're disconnected.
    config.disconnected ||= ->
    # Additional options.
    config.options      ||= {}
    # URL that we'll connect to.
    config.uri          ||= undefined
    # Params that we'll tack on to the URL.
    config.params       ||= {}
    # Hang on to these config for when we connect.
    @config = config
    # Make sure we return ourself out of the constructor so we can chain.
    this

  connect: =>
    # Figure out what transport is supported and return it.
    # TODO if the initial connection fails, try the next transport mmmkay?
    for transport in @config.transports
      if transport = Firehose[transport]
        return new transport(@config).connect() if transport.supported()