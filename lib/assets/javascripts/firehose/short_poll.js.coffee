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
    @_failCount       = 0

  connect: (delay = 0) =>
    @_failCount = 0
    super delay

  stop: =>
    @_stopRequestLoop = true

  _request: =>
    data = @config.params
    data.short_poll = true
    $.ajax @config.shortPoll.url,
      crossDomain:  true
      data:         data
      timeout:      @config.shortPoll.timeout
      success:      @_success
      error:        @_error

  _error: (jqXhr, status, error) =>
    @config.disconnected()
    time = Math.min (2000 * ++@_failCount), 20000
    setTimeout @_request, time unless @_stopRequestLoop

  _success: (data, status, jqXhr) =>
    @_failCount = 0
    return if @_stopRequestLoop
    @_open data unless @_succeeded
    # TODO: don't send message on 204 response
    @config.message @config.parse jqXhr.responseText
    @connect @config.shortPoll.shortWait

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
