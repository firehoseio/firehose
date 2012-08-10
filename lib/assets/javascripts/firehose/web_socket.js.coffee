# Unfortunately this needs to a global variable. The only other option is to
# hack into the internals of the web_socket.js plugin we are using.
window.WEB_SOCKET_SWF_LOCATION = '/assets/firehose/WebSocketMain.swf' if !window.WEB_SOCKET_SWF_LOCATION

class Firehose.WebSocket extends Firehose.Transport
  @supported: =>
    # Compatibility reference: http://caniuse.com/websockets
    # We don't need to explicitly check for Flash web socket or MozWebSocket
    # because web_socket.js has already handled that.
    !!(window.WebSocket)

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
    @cleanUp()

  _open: =>
    # TODO: include JSON client-side script for less awesome browsers
    @socket.send JSON.stringify ping: 'PING'
    # TODO: consider making this timeout configurable somehow...
    @pingTimeout = setTimeout @_error, 2000

  _waitForPong: (event) =>
    o = try JSON.parse event.data catch e then {}
    if o.pong is 'PONG'
      Firehose.Transport::_open.apply @, event
      clearTimeout @pingTimeout
      @socket.onmessage = @_message

  _message: (event) =>
    @config.message(@config.parse(event.data))

  _close: (event) =>
    if !event || (event and !event.wasClean)
      # This was not a clean disconnect. An error occurred somewhere
      # Lets try to reconnect
      @_error(event)

  _error: (event) =>
    @cleanUp()
    super

  cleanUp: ->
    if @socket
      @socket.onopen    = null
      @socket.onclose   = null
      @socket.onerror   = null
      @socket.onmessage = null
      @socket.close()
      delete(@socket)
