class Firehose.LongPoll extends Firehose.Transport
  messageSequenceHeader: 'pragma'

  # CORS is supported in IE 8+
  @ieSupported: =>
    $.browser.msie and parseInt($.browser.version) > 7 and window.XDomainRequest

  @supported: =>
    # IE 8+, FF 3.5+, Chrome 4+, Safari 4+, Opera 12+, iOS 3.2+, Android 2.1+
    if xhr = $.ajaxSettings.xhr()
      "withCredentials" of xhr || Firehose.LongPoll.ieSupported()

  constructor: (args) ->
    super args

    # Configrations specifically for web sockets
    @config.longPoll ||= {}
    # Protocol schema we should use for talking to WS server.
    @config.longPoll.url ||= "http:#{@config.uri}"
    # How many ms should we wait before timing out the AJAX connection?
    @config.longPoll.timeout ||= 25000

    # TODO - What is @_lagTime for? Can't we just use the @_timeout value?
    # We use the lag time to make the client live longer than the server.
    @_lagTime = 5000
    @_timeout = @config.longPoll.timeout + @_lagTime
    @_okInterval = 0

    @_isConnected = false
    @_stopRequestLoop = false

  connect: (delay = 0) =>
    unless @_isConnected
      @_isConnected = true
      @config.connected()
    super(delay)

  _request: =>
    console?.log "_request", arguments
    # Set the Last Message Sequence in a query string.
    # Ideally we'd use an HTTP header, but android devices don't let us
    # set any HTTP headers for CORS requests.
    data = @config.params
    data.last_message_sequence = @_lastMessageSequence
    # TODO: Some of these options will be deprecated in jQurey 1.8
    #       See: http://api.jquery.com/jQuery.ajax/#jqXHR
    $.ajax @config.longPoll.url,
      crossDomain: true
      data: data
      timeout: @_timeout
      success: @_success
      error: @_error
      xhr: hackedXHR
      complete: (jqXhr) =>
        console?.log "XHR complete", arguments
        # Get the last sequence from the server if specified.
        if jqXhr.status == 200
          @_lastMessageSequence = jqXhr.getResponseHeader(@messageSequenceHeader)
          if @_lastMessageSequence == null
            console?.log 'ERROR: Unable to get last message sequnce from header'
    console?.log "_request END"

  stop: =>
    @_stopRequestLoop = true

  _success: (data, status, jqXhr) =>
    console?.log "_success", arguments
    # TODO we actually want to do this when the thing calls out... mmm right now it takes
    # up to 30s before we can call this thing.
    # Call the 'connected' callback if the connection succeeds.
    @_open(data) unless @_succeeded
    return if @_stopRequestLoop
    if jqXhr.status == 204
      # If we get a 204 back, that means the server timed-out and sent back a 204 with a
      # X-Http-Next-Request header
      #
      # Why did we use a 204 and not a 408? Because FireFox is really stupid about 400 level error
      # codes and would claims its a 0 error code, which we use for something else. Firefox is IE
      # in this case
      @connect(@_okInterval)
    else
      @config.message(@config.parse(jqXhr.responseText))
      @connect(@_okInterval)

  _ping: =>
    console?.log "_ping", arguments
    # Ping long poll server to verify internet connectivity
    # jQuery CORS doesn't support timeouts and there is no way to access xhr2 object
    # directly so we can't manually set a timeout.
    $.ajax @config.longPoll.url,
      method: 'HEAD'
      crossDomain: true
      data: @config.params
      success: @config.connected

  # We need this custom handler to have the connection status
  # properly displayed
  _error: (jqXhr, status, error) =>
    console?.log "_error", arguments
    @_isConnected = false
    @config.disconnected()

    # Ping the server to make sure this isn't a network connectivity error
    setTimeout @_ping, @_retryDelay + @_lagTime

    # Reconnect with delay
    setTimeout @_request, @_retryDelay

# NB: This is a stupid hack to deal with CORS short-comings in jQuery in
# Firefox. There is a ticket for this: http://bugs.jquery.com/ticket/10338
# Once jQuery is upgraded to this version we can probably remove this, but be
# sure you test the crap out of Firefox!
#
# Its also worth noting that I had to localize this monkey-patch to the
# Firehose.LongPoll consumer because a previous global patch on
# jQuery.ajaxSettings.xhr was breaking regular IE7 loading. Better to localize
# this anyway to solve that problem and loading order issues.
hackedXHR = ->
  xhr = jQuery.ajaxSettings.xhr()
  originalFun = xhr.getAllResponseHeaders
  xhr.getAllResponseHeaders = ->
    XHR_HEADERS = [
      "Cache-Control", "Content-Language", "Content-Type"
      "Expires", "Last-Modified", "Pragma"
    ]
    return allHeaders if (allHeaders = originalFun.call xhr)?
    lines = for name in XHR_HEADERS when xhr.getResponseHeader(name)?
      "#{name}: #{xhr.getResponseHeader name}"
    lines.join '\n'
  xhr
