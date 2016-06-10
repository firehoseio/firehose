Transport = require "./transport"

class LongPollTransport extends Transport
  messageSequenceHeader: 'Pragma'
  name: -> 'LongPoll'

  # CORS is kinda supported in IE8+ except that its implementation cannot
  # access "simple request" response headers. This means we don't yet have a
  # plan to support IE<10 (when it gets a real XHR2 implementation). Sucks...
  # $.browser.msie and parseInt($.browser.version) >= 8 # DEPRECATED
  @ieSupported: -> (document.documentMode || 10) >= 8

  @supported: ->
    # IE 8+, FF 3.5+, Chrome 4+, Safari 4+, Opera 12+, iOS 3.2+, Android 2.1+
    if xhr = $.ajaxSettings.xhr()
      "withCredentials" of xhr || LongPollTransport.ieSupported()

  constructor: (args) ->
    super args

    @config.ssl ?= false

    # Configrations specifically for long polling
    @config.longPoll         ||= {}
    @config.longPoll.url     ||= "#{@_protocol()}:#{@config.uri}"
    # How many ms should we wait before timing out the AJAX connection?
    @config.longPoll.timeout ||= 25000
    # TODO - What is @_lagTime for? Can't we just use the @_timeout value?
    # We use the lag time to make the client live longer than the server.
    @_lagTime                  = 5000
    @_timeout                  = @config.longPoll.timeout + @_lagTime
    @_okInterval               = @config.okInterval || 0
    @_stopRequestLoop          = false
    @_lastMessageSequence      = 0

  # Protocol schema we should use for talking to firehose server.
  _protocol: =>
    if @config.ssl then "https" else "http"

  _request: =>
    return if @_stopRequestLoop
    # Set the Last Message Sequence in a query string.
    # Ideally we'd use an HTTP header, but android devices don't let us
    # set any HTTP headers for CORS requests.
    data = @_requestParams()
    data.last_message_sequence = @_lastMessageSequence
    # TODO: Some of these options will be deprecated in jQuery 1.8
    #       See: http://api.jquery.com/jQuery.ajax/#jqXHR
    @_lastRequest = $.ajax
      url:          @config.longPoll.url
      firehose:     true
      crossDomain:  true
      data:         data
      timeout:      @_timeout
      success:      @_success
      error:        @_error
      cache:        false

  _requestParams: =>
    @config.params

  stop: =>
    @_stopRequestLoop = true
    if @_lastRequest?
      try @_lastRequest.abort() catch e
      delete @_lastRequest
    if @_lastPingRequest?
      try @_lastPingRequest.abort() catch e
      delete @_lastPingRequest

  _success: (data, status, jqXhr) =>
    if @_needToNotifyOfReconnect or not @_succeeded
      @_needToNotifyOfReconnect = false
      @_open data
    return if @_stopRequestLoop
    if jqXhr.status is 200
      # Of course, IE's XDomainRequest doesn't support non-200 success codes.
      try
        {message, last_sequence} = JSON.parse jqXhr.responseText
        _checkDroppedMessages(@_lastMessageSequence, last_sequence)
        @_lastMessageSequence    = last_sequence || 0
        @config.message @config.parse message
      catch e
    @connect @_okInterval

  _ping: =>
    # Ping long poll server to verify internet connectivity
    # jQuery CORS doesn't support timeouts and there is no way to access xhr2 object
    # directly so we can't manually set a timeout.
    @_lastPingRequest = $.ajax
      url:          @config.uri
      method:       'HEAD'
      crossDomain:  true
      firehose:     true
      data:         @_requestParams()
      success:      =>
        if @_needToNotifyOfReconnect
          @_needToNotifyOfReconnect = false
          @config.connected @

  # We need this custom handler to have the connection status
  # properly displayed
  _error: (jqXhr, status, error) =>
    unless @_needToNotifyOfReconnect or @_stopRequestLoop
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
if $?.browser?.msie and parseInt($.browser.version, 10) in [8, 9]
  jQuery.ajaxTransport (s) ->
    if s.crossDomain and s.async and s.firehose
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

          # This is critical for long poll to work in IE9.
          # Without it, the initial request will work but
          # subsequent requests will fail silently.
          # http://social.msdn.microsoft.com/Forums/ie/en-US/30ef3add-767c-4436-b8a9-f1ca19b4812e/ie9-rtm-xdomainrequest-issued-requests-may-abort-if-all-event-handlers-not-specified?forum=iewebdevelopment
          xdr.onprogress = -> {}

          if s.xdrTimeout?
            xdr.ontimeout = -> callback 0, "timeout"
            xdr.timeout   = s.xdrTimeout

          xdr.send (s.hasContent and s.data) or null

        abort: ->
          if xdr?
            xdr.onerror = jQuery.noop()
            xdr.abort()
      }

module.exports = LongPollTransport
