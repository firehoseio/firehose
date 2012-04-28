class Firehose.LongPoll extends Firehose.Transport
  # CORS is supported in IE 8+
  @ieSupported: =>
    $.browser.msie and parseInt($.browser.version) > 7 and window.XDomainRequest

  @supported: =>
    # IE 8+, FF 3.5+, Chrome 4+, Safari 4+, Opera 12+, iOS 3.2+, Android 2.1+
    $.support.cors || Firehose.LongPoll.ieSupported()

  constructor: (args) ->
    super args

    # Configrations specifically for web sockets
    @config.longPoll ||= {}
    # Protocol schema we should use for talking to WS server.
    @config.longPoll.url ||= "http:#{@config.uri}"
    # How many ms should we wait before timing out the AJAX connection?
    @config.longPoll.timeout ||= 20000

    # TODO - What is @_lagTime for? Can't we just use the @_timeout value?
    # We use the lag time to make the client live longer than the server.
    @_lagTime = 5000
    @_timeout = @config.longPoll.timeout + @_lagTime
    @_offlineTimer
    @_okInterval = 0

    @registerIETransport()

  registerIETransport: =>
    if Firehose.LongPoll.ieSupported()
      # TODO - Ask Steel what this is for. Looks like some kind of polygot fill, but I want
      # to take the 'json' transport out and do that myself.
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
    
  connect: (delay = 0) =>
    @config.connected()
    super(delay)

  _request: =>
    $.ajax @config.longPoll.url,
      crossDomain: true
      cache: false
      data: @config.params
      timeout: @_timeout
      success: @_success
      error: @_error
  
  _success: (data, status, jqXhr) =>
    # TODO we actually want to do this when the thing calls out... mmm right now it takes
    # up to 30s before we can call this thing.
    # Call the 'connected' callback if the connection succeeds.
    @_open(data) unless @_succeeded
    if jqXhr.status == 204
      # If we get a 204 back, that means the server timed-out and sent back a 204 with a
      # X-Http-Next-Request header
      # 
      # Why did we use a 204 and not a 408? Because FireFox is really stupid about 400 level error
      # codes and would claims its a 0 error code, which we use for something else. Firefox is IE
      # in thise case
      @connect(@_okInterval)
    else
      @config.message(@config.parse(data))
      @connect(@_okInterval)

  # We need this custom handler to have the connection status
  # properly displayed
  _error: (jqXhr, status, error) =>
    clearTimeout(@_offlineTimer)
    @config.disconnected()
    @_offlineTimer = setTimeout(@config.connected, @_retryDelay + @_lagTime)
    @connect(@_retryDelay)