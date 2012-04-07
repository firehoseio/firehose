@module "Push", ->
  class @Client
    constructor: (args) ->
      @transports = ['WebSocket', 'LongPoll']
      
      # Detect the first supported transport give it back 
      transport = _.detect @transports, (transport) ->
        Push[transport].supported()
      
      return new Push[transport](args)
