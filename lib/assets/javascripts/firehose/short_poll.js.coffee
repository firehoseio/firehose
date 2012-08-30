class Firehose.ShortPoll extends Firehose.Transport
  name: -> 'ShortPoll'

  @supported: ->
    not $.browser.msie or parseInt($.browser.version) > 6

  constructor: (args) ->
    super args
    @config.shortPoll           ?= {}
    @config.shortPoll.url       ?= "http:#{@config.uri}"
    @config.shortPoll.timeout   ?= args.timeout or 5000
    @config.shortPoll.shortWait ?= args.wait or 800
    @_stopRequestLoop = false

  stop: =>
    @_stopRequestLoop = true

  _request: =>
    data = @config.params
    data.short_poll = true
    debugger
    $.ajax @config.shortPoll.url,
      crossDomain:  true
      data:         data
      timeout:      @_timeout
      success:      @_success
      error:        @_error

  _timeout: =>
    debugger
    @config.disconnected()
    # TODO: implement some exponential backoff...
    setTimeout @_request, 3000 unless @_stopRequestLoop

  _error: (jqXhr, status, error) =>
    debugger
    @config.disconnected()
    # TODO: implement some exponential backoff...
    setTimeout @_request, 1000 unless @_stopRequestLoop

  _success: (data, status, jqXhr) =>
    debugger
    return if @_stopRequestLoop
    @_open data unless @_succeeded
    @config.message @config.parse jqXhr.responseText
    @connect @_okInterval, @config.shortPoll.shortWait

# NB: Leaving this here for now. It does work, but won't help us since the XDR
#     object cannot access any response headers, which Firehose relies on.

# # Let's try to hack in support for IE8+ via the XDomainRequest object!
# # This was adapted from code shamelessly stolen from:
# # https://github.com/jaubourg/ajaxHooks/blob/master/src/ajax/xdr.js
# if $.browser.msie and parseInt($.browser.version, 10) in [8, 9]
#   jQuery.ajaxTransport (s) ->
#     if s.crossDomain and s.async
#       if s.timeout
#         s.xdrTimeout = s.timeout
#         delete s.timeout
#       xdr = undefined
#       return {
#         send: (_, complete) ->
#           callback = (status, statusText, responses, responseHeaders) ->
#             xdr.onload = xdr.onerror = xdr.ontimeout = jQuery.noop
#             xdr = undefined
#             complete status, statusText, responses, responseHeaders
#           xdr = new XDomainRequest()
#           xdr.open s.type, s.url
#           xdr.onload = ->
#             headers = "Content-Type: #{xdr.contentType}"
#             callback 200, "OK", {text: xdr.responseText}, headers
#           xdr.onerror = -> callback 404, "Not Found"
#           if s.xdrTimeout?
#             xdr.ontimeout = -> callback 0, "timeout"
#             xdr.timeout   = s.xdrTimeout
#           xdr.send (s.hasContent and s.data) or null
#         abort: ->
#           if xdr?
#             xdr.onerror = jQuery.noop()
#             xdr.abort()
#       }
