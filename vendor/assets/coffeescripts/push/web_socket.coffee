@module "Push", ->
  class @WebSocket extends @Transport
    @flashSupported: =>
      $.browser.msie

    @supported: =>
      # Compatibility reference: http://caniuse.com/websockets
      # Native websocket support + Flash web socket
      window.WebSocket || (window["MozWebSocket"] and window.MozWebSocket) || WebSocket.flashSupported()

    constructor: (args) ->
      super args

      # Mozilla decided to have their own implementation of Web Sockets so detect for that
      window.WebSocket = window.MozWebSocket if window["MozWebSocket"] and window.MozWebSocket

    _request: =>
      @socket = new window.WebSocket(@url["websocket"] + "?" + $.param(@params))
      @socket.onopen = @_open
      @socket.onclose = @_close
      @socket.onerror = @_error
      @socket.onmessage = @_message

    _message: (event) =>
      try
        @onMessage($.parseJSON(event.data))
      catch e      
  
    _close: (event) =>
      if !event || (event and !event.wasClean)
        # This was not a clean disconnect. An error occurred somewhere
        # Lets try to reconnect
        @_error(event)