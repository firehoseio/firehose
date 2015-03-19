Firehose.multiplexChannel = "channels@firehose"

class Firehose.MultiplexedConsumer extends Firehose.Consumer
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
    @config.uri += Firehose.multiplexChannel

    @config.params = Firehose.MultiplexedConsumer.subscriptionQuery(@config)

    Firehose.MultiplexedConsumer.normalizeChannels(@config)
    for channel, opts of @config.channels
      @_addSubscriptionHandler(channel, opts)

    super(@config)

  websocketTransport: (config) =>
    new Firehose.MultiplexedWebSocket(config)

  longpollTransport: (config) =>
    new Firehose.MultiplexedLongPoll(config)

  message: (msg) =>
    if handler = @messageHandlers[msg.channel]
      handler(@config.parse msg.message)

  _addSubscriptionHandler: (channel, opts) =>
    if opts.message
      @messageHandlers[channel] = opts.message

  _removeSubscriptionHandler: (channelNames...) =>
    for chan in channelNames
      delete @messageHandlers[chan]

  _updateParams: =>
    Firehose.MultiplexedConsumer.normalizeChannels(@config)
    @config.params = Firehose.MultiplexedConsumer.subscriptionQuery(@config)

  subscribe: (channel, opts = {}) =>
    channel = Firehose.MultiplexedConsumer.normalizeChannel(channel)
    @config.channels[channel] = opts

    @_updateParams()
    @_addSubscriptionHandler(channel, opts)
    @transport.subscribe(channel, opts)

  unsubscribe: (channelNames...) =>
    for channel in channelNames
      channel = Firehose.MultiplexedConsumer.normalizeChannel(channel)
      delete @config.channels[channel]

    @_updateParams()
    @_removeSubscriptionHandler(channelNames...)
    @transport.unsubscribe(channelNames...)
