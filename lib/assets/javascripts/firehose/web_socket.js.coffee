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

  # Ping-pong the server over web sockets and call successCB if it worked!
  @test: (config, successCB) ->
    return unless Firehose.WebSocket.supported()
    url = "ws:#{config.uri}?#{$.param config.params}"
    socket = new window.WebSocket url
    socket.onmessage = (event) ->
      if isPong(try JSON.parse event.data catch e then {})
        socket.onopen = socket.onmessage = null
        socket.close()
        successCB()
    socket.onopen = ->
      sendPing socket
    return

  constructor: (args) ->
    super args
    # Configrations specifically for web sockets
    @config.webSocket ||= {}
    # What sequence number to start from when upgrading from LongPoll
    if @config.lastMessageSequence?
      @_startFromSequence = @config.lastMessageSequence

  _getURL: =>
    obj = {}
    obj[k] = v for k, v of @config.params
    obj.last_message_sequence = @_startFromSequence if @_startFromSequence?
    "ws:#{@config.uri}?#{$.param obj}"

  _request: =>
    @socket = new window.WebSocket @_getURL()
    @socket.onopen    = @_open
    @socket.onclose   = @_close
    @socket.onerror   = @_error
    @socket.onmessage = @_message

  stop: =>
    @_cleanUp()

  _open: =>
    @_restartKeepAlive()
    super

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
