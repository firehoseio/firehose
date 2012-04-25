class Firehose.Transport
  # Class method to determine whether transport is supported by the current browser. Note that while
  # the transport may be supported by the browser, its possible that the network connection won't 
  # succeed. That should be accounted for during the initial connecting to the server.
  @supported: =>
    false

  constructor: (args) ->
    @_retryDelay = 5000 

  # Default the callbacks to an empty function so that non-configured options don't break.
  onDisconnected: ->
  onConnected: ->
  onMessage: ->
  onError: ->

  # Chainable configuration.
  disconnected: (@onDisconnected) -> this
  connected:    (@onConnected)    -> this
  message:      (@onMessage)      -> this
  options:      (@options)        -> this
  params:       (@params)         -> this
  error:        (@onError)        -> this
  url:          (@url)            -> this

  # Lets rock'n'roll! Connect to the server.
  connect: (delay = 0) =>
    setTimeout =>
      @_request()
    , delay
    this

  # Sub classes need to implement this method to handle requests
  _request: =>

  # Default error handler
  _error: (event) =>
    # Lets try to connect again with delay
    @onDisconnected()
    @connect(@_retryDelay)

  # Default connection established handler
  _open: (event) =>
    @onConnected()

  # Default connection closed handler
  _close: (event) =>
    @onDisconnected()