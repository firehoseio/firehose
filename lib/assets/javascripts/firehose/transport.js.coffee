class Firehose.Transport
  # Class method to determine whether transport is supported by the current browser. Note that while
  # the transport may be supported by the browser, its possible that the network connection won't 
  # succeed. That should be accounted for during the initial connecting to the server.
  @supported: =>
    false

  constructor: (config={}) ->
    @config = config
    @_retryDelay = 5000 

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
    unless @_succeeded
      # Fail peremantly if the error happens on the first connection.
      @config.failed(this)
    else
      # Lets try to connect again with delay
      @config.disconnected()
      @connect(@_retryDelay)

  # Default connection established handler
  _open: (event) =>
    @_succeeded = true
    @config.connected()

  # Default connection closed handler
  _close: (event) =>
    @config.disconnected()