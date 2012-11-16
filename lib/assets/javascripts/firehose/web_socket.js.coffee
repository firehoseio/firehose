# Unfortunately this needs to a global variable. The only other option is to
# hack into the internals of the web_socket.js plugin we are using.
window.WEB_SOCKET_SWF_LOCATION = '/assets/firehose/WebSocketMain.swf' if !window.WEB_SOCKET_SWF_LOCATION

INITIAL_PING_TIMEOUT   =  2000
KEEPALIVE_PING_TIMEOUT = 20000

class Firehose.WebSocket extends Firehose.Transport
  name: -> 'WebSocket'

  @supported: ->
    # Compatibility reference: http://caniuse.com/websockets
    # We don't need to explicitly check for Flash web socket or MozWebSocket
    # because web_socket.js has already handled that.
    window.WebSocket?

  constructor: (args) ->
    super args
    # Configrations specifically for web sockets
    @config.webSocket ||= {}
    @config.webSocket.connectionVerified = @config.connectionVerified

  _request: =>
    console.log "WebSocket#_request", arguments
    @socket = new window.WebSocket "ws:#{@config.uri}?#{$.param @config.params}"
    @socket.onopen    = @_open
    @socket.onclose   = @_close
    @socket.onerror   = @_error
    @socket.onmessage = @_lookForInitialPong

  _open: =>
    console.log "WebSocket#_open", arguments
    sendPing @socket

  _lookForInitialPong: (event) =>
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
    console.log "WebSocket#stop", arguments
    @_cleanUp()

  _message: (event) =>
    console.log "WebSocket#_message", arguments
    frame = @config.parse event.data
    @_restartKeepAlive()
    unless isPong frame
      try
        @_lastMessageSequence = frame.last_sequence
        @config.message @config.parse frame.message
      catch e

  _close: (event) =>
    console.log "WebSocket#_close", arguments
    if event?.wasClean then @_cleanUp()
    else @_error event

  _error: (event) =>
    console.log "WebSocket#_error", arguments
    @_cleanUp()
    if @_needToNotifyOfDisconnect
      @_needToNotifyOfDisconnect = false
      @config.disconnected()
    if @_succeeded
      # Lets try to connect again with delay
      @connect(@_retryDelay)
    else @config.failed @

  _cleanUp: =>
    console.log "WebSocket#_cleanUp" 
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
