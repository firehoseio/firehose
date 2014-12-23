describe 'Firehose.MultiplexedConsumer', ->

  beforeEach ->
    @receivedMessages = []

    @instance = new Firehose.MultiplexedConsumer
      uri: '/'
      okInterval: 9999 # Stop crazy ajax loops during tests
      subscribe: [
        channel: "/foo"
        last_sequence: 0
        message: (msg) =>
          @receivedMessages.push msg
      ,
        channel: "/bar"
        last_sequence: 10
        message: (msg) =>
          @receivedMessages.push msg
      ]

  #= Specs ===

  describe 'new instance', ->
    it "receives only messages from channels it is currently subscribed to", ->
      @instance.connect()

      for i in [1..5]
        @instance.message({channel: "/foo", message: "msg-#{i}"})
      for i in [6..10]
        @instance.message({channel: "/bar", message: "msg-#{i}"})

      @instance.unsubscribe("/foo")

      for i in [11..15]
        @instance.message({channel: "/foo", message: "msg-#{i}"})
      for i in [16..20]
        @instance.message({channel: "/bar", message: "msg-#{i}"})

      expect(@receivedMessages).toEqual [
        "msg-1", "msg-2", "msg-3", "msg-4", "msg-5",
        "msg-6", "msg-7", "msg-8", "msg-9", "msg-10",
        "msg-16", "msg-17", "msg-18", "msg-19", "msg-20",
      ]