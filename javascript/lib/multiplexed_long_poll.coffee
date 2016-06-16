LongPollTransport = require "./long_poll_transport"

class MultiplexedLongPoll extends LongPollTransport
  constructor: (args) ->
    super args
    @_lastMessageSequence = {}

  subscribe: (channel, opts) =>
    # nothing to be done

  unsubscribe: (channelNames...) =>
    # same here

  _request: =>
    return if @_stopRequestLoop
    data = @_subscriptions()

    @_lastRequest = $.ajax
      url:          @config.uri
      firehose:     true
      crossDomain:  true
      method:       "POST"
      data:         data
      dataType:     "json"
      timeout:      @_timeout
      success:      @_success
      error:        @_error
      cache:        false

  _updateLastMessageSequences: =>
    for channel, opts of @config.channels
      if seq = @_lastMessageSequence[channel]
        opts.last_sequence = seq
      else
        unless opts.last_sequence
          opts.last_sequence = 0

  _subscriptions: =>
    @_updateLastMessageSequences()
    subs = {}
    for channel, opts of @config.channels
      subs[channel] = opts.last_sequence || 0
    JSON.stringify(subs)

  _success: (data, status, jqXhr) =>
    if @_needToNotifyOfReconnect or not @_succeeded
      @_needToNotifyOfReconnect = false
      @_open data
    return if @_stopRequestLoop
    if jqXhr.status is 200
      # Of course, IE's XDomainRequest doesn't support non-200 success codes.
      try
        message = JSON.parse jqXhr.responseText
        @_lastMessageSequence ||= {}
        @_lastMessageSequence[message.channel] = message.last_sequence
        @config.message message
      catch e
    @connect @_okInterval

module.exports = MultiplexedLongPoll
