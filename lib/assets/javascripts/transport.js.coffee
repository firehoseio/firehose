@module "Push", ->
  class @Transport
    # Class method to determine whether transport is supported by the current browser
    @supported: =>
      false

    constructor: (args) ->
      @_errorInterval = 5000 

    # Chainable config
    connected: (@onConnected) -> this
    disconnected: (@onDisconnected) -> this
    message: (@onMessage) -> this
    error: (@onError) -> this
    url: (@url) -> this
    params: (@params) -> this
    options: (@options) -> this

    # Lets rock'n'roll
    connect: (delay = 0) =>
      setTimeout =>
        @_request()
      , delay

    # Sub classes need to implement this method to handle requests
    _request: =>
      
    # Default error handler
    _error: (event) =>
      # Lets try to connect again with delay
      @onDisconnected()
      @connect(@_errorInterval)
    
    # Default connection established handler
    _open: (event) =>
      @onConnected()

    # Default connection closed handler
    _close: (event) =>
      @onDisconnected()