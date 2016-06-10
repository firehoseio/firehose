Transport = require "./transport"
WebSocket = require "ws"

INITIAL_PING_TIMEOUT   =  2000
KEEPALIVE_PING_TIMEOUT = 20000

sendPing = (socket) ->
  socket.send JSON.stringify ping: 'PING'

class WebSocketTransport extends Transport
  name: -> 'WebSocket'

  @ieSupported:-> (document.documentMode || 10) > 9
  @supported  :-> WebSocket? # Check if WebSocket is an object in the window.

  constructor: (args) ->
    super args
    # Configrations specifically for web sockets
    @config.webSocket ||= {}
    @config.webSocket.connectionVerified = @config.connectionVerified

  _sendMessage: (message) =>
    @socket?.send(JSON.stringify message)

  _request: =>
    # Run this in a try/catch block because IE10 inside of a .NET control
    # complains about security zones.
    try
      @socket = new WebSocket "#{@_protocol()}:#{@config.uri}?#{$.param @_requestParams()}"
      @socket.onopen    = @_open
      @socket.onclose   = @_close
      @socket.onerror   = @_error
      @socket.onmessage = @_lookForInitialPong
    catch err
      console?.log(err)

  # Protocol schema we should use for talking to firehose server.
  _protocol: =>
    if @config.ssl then "wss" else "ws"

  _requestParams: =>
    @config.params

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
    @_sendMessage({message_sequence})
    @_needToNotifyOfDisconnect = true
    Transport::_open.call @

  stop: =>
    @_cleanUp()

  _message: (event) =>
    frame = @config.parse event.data
    @_restartKeepAlive()
    unless isPong frame
      try
        _checkDroppedMessages(@_lastMessageSequence, frame.last_sequence)
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
    if @_succeeded
      @connect @_retryDelay
    else if @config.failed
      @config.failed @

  _cleanUp: =>
    @_clearKeepalive()
    if @socket?
      @socket.onopen    = null
      @socket.onclose   = null
      @socket.onerror   = null
      @socket.onmessage = null
      @socket.close()
      # delete @socket

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

module.exports = WebSocketTransport
