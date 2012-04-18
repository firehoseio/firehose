class Firehose.Client
  constructor: (args) ->
    @transports = ['WebSocket', 'LongPoll']

    # Figure out what transport is supported and return it.
    for transport in @transports
      if transport = Firehose[transport]
        return new transport(args) if transport.supported()