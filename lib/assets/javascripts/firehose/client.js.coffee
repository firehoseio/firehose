class Firehose.Client
  # Transports that are available to Firehose.
  @transports: ['WebSocket', 'LongPoll']

  # Generate a random client_id.
  @nextClientId: ->
    Math.floor((Math.random()*99999999999)+1)

  constructor: (config={}) ->
    # The clientId is used by the server to remember messages between requests. In a production environment,
    # this should probably be some combination of "user_id-rand". Why the rand? Because a user may have multiple
    # tabs open to the application, and each tab needs a different channel on the server.
    config.clientId    ||= Firehose.Client.nextClientId()
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
    # Params that we'll tack on to the URL. We include a clientId in here for kicks.
    config.params       ||= { cid: config.clientId }
    # Do stuff before we send the message into config.message. The sensible
    # default on the webs is to parse JSON.
    config.parse ||= (body) ->
      $.parseJSON(body)
    
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