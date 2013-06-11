INITIAL_PING_TIMEOUT   =  2000
KEEPALIVE_PING_TIMEOUT = 20000

class Firehose.WebSocket extends Firehose.Transport
  name: -> 'WebSocket'

  # Check if WebSocket is an object in the window.
  @supported: ->
    window.WebSocket?

  constructor: (args) ->
    # Prevent triggering of socket onclose
    # event when navigating back to the page
    # http://stackoverflow.com/questions/4812686/closing-websocket-correctly-html5-javascript
    window.onbeforeunload = =>
      @_cleanUp()
      null # prevent "Are you sure?" dialog

    # pagehide only exists for these iOS devices
    # but it is triggered much more reliably than onbeforeunload
    if (/iphone|ipod|ipad.*os 5/gi).test(navigator.appVersion)
      window.onpagehide = =>
        @_cleanUp()

    super args
    # Configrations specifically for web sockets
    @config.webSocket ||= {}
    @config.webSocket.connectionVerified = @config.connectionVerified

  _request: =>
    # Run this is a try/catch block because IE10 inside of a .NET control
    # complains about security zones.
    try
      @socket = new window.WebSocket "ws:#{@config.uri}?#{$.param @config.params}"
      @socket.onopen    = @_open
      @socket.onclose   = @_close
      @socket.onerror   = @_error
      @socket.onmessage = @_lookForInitialPong
    catch err
      console?.log(err)

  _open: =>
    sendPing @socket

  _lookForInitialPong: (event) =>
    @_restartKeepAlive()
    if isPong(try JSON.parse event.data catch e then {})
      if @_lastMessageSequence?
        # don't callback to connectionVerified on subsequent reconnects
        @sendStartingMessageSequence @_lastMessageSequence
      else @config.webSocket.connectionVerified @

  sendStartingMessageSequence: (message_sequence) =>
    @_lastMessageSequence = message_sequence
    @socket.onmessage     = @_message
    @socket.send JSON.stringify {message_sequence}
    @_needToNotifyOfDisconnect = true
    Firehose.Transport::_open.call @

  stop: =>
    @_cleanUp()

  _message: (event) =>
    frame = @config.parse event.data
    @_restartKeepAlive()
    unless isPong frame
      try
        @_lastMessageSequence = frame.last_sequence
        @config.message @config.parse frame.message
      catch e

  _close: (event) =>
    if event?.wasClean then @_cleanUp()
    else @_error event

  _error: (event) =>
    @_cleanUp()
    if @_needToNotifyOfDisconnect
      @_needToNotifyOfDisconnect = false
      @config.disconnected()
    if @_succeeded then @connect @_retryDelay
    else @config.failed @

  _cleanUp: =>
    @_clearKeepalive()
    if @socket?
      @socket.onopen    = null
      @socket.onclose   = null
      @socket.onerror   = null
      @socket.onmessage = null
      @socket.close()
      delete @socket

  _restartKeepAlive: =>
    doPing = =>
      sendPing @socket
      setNextKeepAlive()
    setNextKeepAlive = =>
      @keepaliveTimeout = setTimeout doPing, KEEPALIVE_PING_TIMEOUT
    @_clearKeepalive()
    setNextKeepAlive()

  _clearKeepalive: =>
    if @keepaliveTimeout?
      clearTimeout @keepaliveTimeout
      @keepaliveTimeout = null

sendPing = (socket) ->
  socket.send JSON.stringify ping: 'PING'

isPong = (o) ->
  o.pong is 'PONG'
