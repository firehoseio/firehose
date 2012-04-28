class Firehose.WebSocket extends Firehose.Transport
  @flashSupported: =>
    $.browser.msie

  @supported: =>
    # Compatibility reference: http://caniuse.com/websockets
    # Native websocket support + Flash web socket
    !!(window.WebSocket || (window["MozWebSocket"] and window.MozWebSocket) || WebSocket.flashSupported())

  constructor: (args) ->
    super args

    # Configrations specifically for web sockets
    @config.webSocket ||= {}
    # Protocol schema we should use for talking to WS server.
    @config.webSocket.url ||= "ws:#{@config.uri}?#{$.param(@config.params)}"
    # Path of the swf WebSocket that we use in non-WS flash browsers.
    @config.webSocket.swf_path ||= "/flash/firehose/WebSocketMain.swf"

    # Set flash socket path for the WS SWF polyfill.
    WebSocket.__swfLocation = @config.webSocket.swf_path

    # Mozilla decided to have their own implementation of Web Sockets so detect for that.
    window.WebSocket = window.MozWebSocket if window["MozWebSocket"] and window.MozWebSocket

  _request: =>
    @socket = new window.WebSocket(@config.webSocket.url)
    @socket.onopen = @_open
    @socket.onclose = @_close
    @socket.onerror = @_error
    @socket.onmessage = @_message

  _message: (event) =>
    @config.message(@config.parse(event.data))

  _close: (event) =>
    if !event || (event and !event.wasClean)
      # This was not a clean disconnect. An error occurred somewhere
      # Lets try to reconnect
      @_error(event)

  _error: (event) =>
    # Cleanup the current connection
    if @socket
      @socket.onopen = null
      @socket.onclose = null
      @socket.onerror = null
      @socket.onmessage = null
      @socket.close()
      delete(@socket)
    
    super