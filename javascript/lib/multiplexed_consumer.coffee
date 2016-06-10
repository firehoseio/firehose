Consumer = require "./consumer"
MultiplexedWebSocket = require "./multiplexed_web_socket"
MultiplexedLongPoll = require "./multiplexed_long_poll"

class MultiplexedConsumer extends Consumer
  @subscriptionQuery: (config) ->
    {
      subscribe: [
        "#{channel}!#{opts.last_sequence || 0}" for channel, opts of config.channels
      ].join(",")
    }

  @normalizeChannels: (config) ->
    for chan, opts of config.channels
      if chan[0] != "/"
        delete config.channels[chan]
        config.channels["/" + chan] = opts

  @normalizeChannel: (channel) ->
    if channel[0] != "/"
      return "/" + channel
    else
      return channel

  constructor: (@config = {}) ->
    @messageHandlers = {}
    @config.message ||= @message
    @config.channels ||= {}
    @config.uri += Consumer.multiplexChannel

    @_updateSubscriptions()

    for channel, opts of @config.channels
      @_addSubscriptionHandler(channel, opts)

    super(@config)

  websocketTransport: (config) =>
    new MultiplexedWebSocket(config)

  longpollTransport: (config) =>
    new MultiplexedLongPoll(config)

  message: (msg) =>
    if handler = @messageHandlers[msg.channel]
      handler(@config.parse msg.message)

  _addSubscriptionHandler: (channel, opts) =>
    if opts.message
      @messageHandlers[channel] = opts.message

  _removeSubscriptionHandler: (channelNames...) =>
    for chan in channelNames
      delete @messageHandlers[chan]

  _updateSubscriptions: =>
    MultiplexedConsumer.normalizeChannels(@config)

  subscribe: (channel, opts = {}) =>
    channel = MultiplexedConsumer.normalizeChannel(channel)
    @config.channels[channel] = opts

    @_updateSubscriptions()
    @_addSubscriptionHandler(channel, opts)
    @transport.subscribe(channel, opts)

  unsubscribe: (channelNames...) =>
    return unless @connected()

    for channel in channelNames
      channel = MultiplexedConsumer.normalizeChannel(channel)
      delete @config.channels[channel]

    @_updateSubscriptions()
    @_removeSubscriptionHandler(channelNames...)
    @transport.unsubscribe(channelNames...)

module.exports = MultiplexedConsumer
