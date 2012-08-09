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
    @socket = new window.WebSocket(@config.webSocket.url)
    @socket.onopen = @_open
    @socket.onclose = @_close
    @socket.onerror = @_error
    @socket.onmessage = @_message

  stop: =>
    @cleanUp()

  _message: (event) =>
    if @_succeeded then @config.message @config.parse event.data
    else
      @config.connected @
      @_succeeded = true # I'm a success!
      # Give the connected callback a chance to finish before sending a message
      setTimeout =>
        @config.message @config.parse event.data
      , 0

  _open: (event) =>
    # Unfortunately, receiving an open event isn't as meaningful as you'd
    # think. So let's not get ahead of ourselves here...
    @_succeeded = false

  _close: (event) =>
    # This was not a clean disconnect. Let's try to reconnect
    @_error event unless event?.wasClean

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
      delete @socket
