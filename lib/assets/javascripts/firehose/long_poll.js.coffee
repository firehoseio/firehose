class Firehose.LongPoll extends Firehose.Transport
  messageSequenceHeader: 'Pragma'
  name: -> 'LongPoll'

  # CORS is kinda supported in IE8+ except that its implementation cannot
  # access "simple request" response headers. This means we don't yet have a
  # plan to support IE<10 (when it gets a real XHR2 implementation). Sucks...
  @ieSupported: ->
    $.browser.msie and parseInt($.browser.version) >= 8

  @supported: ->
    # IE 8+, FF 3.5+, Chrome 4+, Safari 4+, Opera 12+, iOS 3.2+, Android 2.1+
    if xhr = $.ajaxSettings.xhr()
      "withCredentials" of xhr || Firehose.LongPoll.ieSupported()

  constructor: (args) ->
    super args
    # Configrations specifically for web sockets
    @config.longPoll         ||= {}
    # Protocol schema we should use for talking to WS server.
    @config.longPoll.url     ||= "http:#{@config.uri}"
    # How many ms should we wait before timing out the AJAX connection?
    @config.longPoll.timeout ||= 25000
    # TODO - What is @_lagTime for? Can't we just use the @_timeout value?
    # We use the lag time to make the client live longer than the server.
    @_lagTime         = 5000
    @_timeout         = @config.longPoll.timeout + @_lagTime
    @_okInterval      = 0
    @_stopRequestLoop = false

  _request: =>
    return if @_stopRequestLoop
    # Set the Last Message Sequence in a query string.
    # Ideally we'd use an HTTP header, but android devices don't let us
    # set any HTTP headers for CORS requests.
    data = @config.params
    data.last_message_sequence = @_lastMessageSequence
    # TODO: Some of these options will be deprecated in jQuery 1.8
    #       See: http://api.jquery.com/jQuery.ajax/#jqXHR
    $.ajax
      url:          @config.longPoll.url
      crossDomain:  true
      data:         data
      timeout:      @_timeout
      success:      @_success
      error:        @_error
      cache:        false

  stop: =>
    @_stopRequestLoop = true

  _success: (data, status, jqXhr) =>
    if @_needToNotifyOfReconnect or not @_succeeded
      @_needToNotifyOfReconnect = false
      @_open data
    return if @_stopRequestLoop
    if jqXhr.status is 200
      # Of course, IE's XDomainRequest doesn't support non-200 success codes.
      try
        {message, last_sequence} = JSON.parse jqXhr.responseText
        @_lastMessageSequence    = last_sequence
        @config.message @config.parse message
      catch e
    @connect @_okInterval

  _ping: =>
    # Ping long poll server to verify internet connectivity
    # jQuery CORS doesn't support timeouts and there is no way to access xhr2 object
    # directly so we can't manually set a timeout.
    $.ajax
      url:          @config.longPoll.url
      method:       'HEAD'
      crossDomain:  true
      data:         @config.params
      success:      =>
        if @_needToNotifyOfReconnect
          @_needToNotifyOfReconnect = false
          @config.connected @

  # We need this custom handler to have the connection status
  # properly displayed
  _error: (jqXhr, status, error) =>
    unless @_needToNotifyOfReconnect
      @_needToNotifyOfReconnect = true
      @config.disconnected()
    unless @_stopRequestLoop
      # Ping the server to make sure this isn't a network connectivity error
      setTimeout @_ping, @_retryDelay + @_lagTime
      # Reconnect with delay
      setTimeout @_request, @_retryDelay

# Let's try to hack in support for IE8-9 via the XDomainRequest object!
# This was adapted from code shamelessly stolen from:
# https://github.com/jaubourg/ajaxHooks/blob/master/src/ajax/xdr.js
if $.browser.msie and parseInt($.browser.version, 10) in [8, 9]
  jQuery.ajaxTransport (s) ->
    if s.crossDomain and s.async
      if s.timeout
        s.xdrTimeout = s.timeout
        delete s.timeout
      xdr = undefined
      return {
        send: (_, complete) ->
          callback = (status, statusText, responses, responseHeaders) ->
            xdr.onload = xdr.onerror = xdr.ontimeout = jQuery.noop
            xdr = undefined
            complete status, statusText, responses, responseHeaders
          xdr = new XDomainRequest()
          xdr.open s.type, s.url
          xdr.onload = ->
            headers = "Content-Type: #{xdr.contentType}"
            callback 200, "OK", {text: xdr.responseText}, headers
          xdr.onerror = -> callback 404, "Not Found"
          if s.xdrTimeout?
            xdr.ontimeout = -> callback 0, "timeout"
            xdr.timeout   = s.xdrTimeout
          xdr.send (s.hasContent and s.data) or null
        abort: ->
          if xdr?
            xdr.onerror = jQuery.noop()
            xdr.abort()
      }
