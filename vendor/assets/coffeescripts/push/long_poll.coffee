@module "Push", ->
  class @LongPoll extends @Transport
    # CORS is supported in IE 8+
    @ieSupported: =>
      $.browser.msie and parseInt($.browser.version) > 7 and window.XDomainRequest

    @supported: =>
      # IE 8+, FF 3.5+, Chrome 4+, Safari 4+, Opera 12+, iOS 3.2+, Android 2.1+
      $.support.cors || LongPoll.ieSupported()

    constructor: (args) ->
      super args

      # We use the lag time to make the client live longer than the server.
      @_lagTime = 5000
      @_timeout = @options.timeout + @_lagTime
      @_dataType = "json"
      @_offlineTimer
      @_okInterval = 0

      @registerIETransport()

    registerIETransport: =>
      if LongPoll.ieSupported()
        $.ajaxTransport 'json', (options, orignalOptions, jqXhr) ->
          xdr = null
          send: (_, callback) ->
            xdr = new XDomainRequest()
            xdr.onload = ->
              statusCode = if xdr.responseText.length > 0 then 200 else 204
              callback(statusCode, 'success', text: xdr.responseText)
            
            xdr.onerror = xdr.ontimeout = ->
              callback(400, 'failed', text: xdr.responseText)

            xdr.open(options.type, options.url)
            xdr.send(options.data)
          
          abort: ->
            if xdr
              xdr.onerror = $.noop()
              xdr.abort()

        # also, override the support check
        $.support.cors = true;
      
    _request: =>
      $.ajax @url["longpoll"], 
        crossDomain: true
        cache: false
        dataType: @_dataType
        data: @params
        timeout: @_timeout
        success: @_success
        error: @_error
    
    _success: (data, status, jqXhr) =>
      if jqXhr.status == 204
        # If we get a 204 back, that means the server timed-out and sent back a 204 with a
        # X-Http-Next-Request header
        # 
        # Why did we use a 204 and not a 408? Because FireFox is really stupid about 400 level error
        # codes and would claims its a 0 error code, which we use for something else. Firefox is IE
        # in thise case
        @connect(@_okInterval)
      else
        @onMessage(data)
        @connect(@_okInterval)

    # We need this custom handler to have the connection status
    # properly displayed
    _error: (jqXhr, status, error) =>
      clearTimeout(@_offlineTimer)
      @onDisconnected()
      @_offlineTimer = setTimeout(@onConnected, @_errorInterval + @_lagTime)
      @connect(@_errorInterval)
