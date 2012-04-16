class Firehose.Client
  constructor: (args) ->
    @transports = ['WebSocket', 'LongPoll']
    
    # Detect the first supported transport give it back 
    transport = _.detect @transports, (transport) ->
      Firehose[transport].supported()
    
    return new Firehose[transport](args)