# Unfortunately this needs to a global variable. The only other option is to
# hack into the internals of the web_socket.js plugin we are using.
window.WEB_SOCKET_SWF_LOCATION = '/assets/firehose/WebSocketMain.swf' if !window.WEB_SOCKET_SWF_LOCATION

INITIAL_PING_TIMEOUT      =  2000
KEEPALIVE_PING_TIMEOUT = 20000

class Firehose.WebSocket extends Firehose.Transport
  name: -> 'WebSocket'

  @supported: =>
    # Compatibility reference: http://caniuse.com/websockets
    # We don't need to explicitly check for Flash web socket or MozWebSocket
    # because web_socket.js has already handled that.
    window.WebSocket?

  constructor: (args) ->
    super args
    # Configrations specifically for web sockets
    @config.webSocket ||= {}
    # Protocol schema we should use for talking to WS server.
    @config.webSocket.url ||= "ws:#{@config.uri}?#{$.param(@config.params)}"

  _request: =>
    @socket = new window.WebSocket @config.webSocket.url
    @socket.onopen    = @_open
    @socket.onclose   = @_close
    @socket.onerror   = @_error
    @socket.onmessage = @_waitForPong

  stop: =>
    @_cleanUp()

  _open: =>
    @_sendPing()
    # TODO: consider making this timeout configurable somehow...
    @pingTimeout = setTimeout @_error, INITIAL_PING_TIMEOUT

  _waitForPong: (event) =>
    if isPong(try JSON.parse event.data catch e then {})
      @_succeeded = true
      @config.connected @
      clearTimeout @pingTimeout
      @socket.onmessage = @_message
      @_restartKeepAlive()
    else @_message event

  _message: (event) =>
    @_restartKeepAlive()
    msg = @config.parse event.data
    @config.message msg if not isPong msg

  _close: (event) =>
    if event?.wasClean then @_cleanUp()
    else @_error event

  _error: (event) =>
    @_cleanUp()
    super

  _cleanUp: =>
    if @socket?
      @socket.onopen    = null
      @socket.onclose   = null
      @socket.onerror   = null
      @socket.onmessage = null
      @socket.close()
      delete @socket

  _sendPing: =>
    @socket.send JSON.stringify ping: 'PING'

  _restartKeepAlive: =>
    doPing = =>
      console.log "Sending keepalive ping!"
      @_sendPing()
      setNextKeepAlive()
    setNextKeepAlive = =>
      @keepaliveTimeout = setTimeout doPing, KEEPALIVE_PING_TIMEOUT
    if @keepaliveTimeout?
      clearTimeout @keepaliveTimeout
      @keepaliveTimeout = null
    setNextKeepAlive()

isPong = (o) ->
  o.pong is 'PONG'
