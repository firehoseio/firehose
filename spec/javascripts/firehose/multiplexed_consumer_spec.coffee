describe 'Firehose.MultiplexedConsumer', ->

  beforeEach ->
    @receivedMessages = []

    @instance = new Firehose.MultiplexedConsumer
      uri: '/'
      okInterval: 9999 # Stop crazy ajax loops during tests
      channels:
        "/foo":
          last_sequence: 0
          message: (msg) =>
            @receivedMessages.push msg
        "/bar":
          last_sequence: 10
          message: (msg) =>
            @receivedMessages.push msg

  #= Specs ===

  describe 'new instance', ->
    it "receives only messages from channels it is currently subscribed to", ->
      @instance.connect().then =>
        for i in [1..5]
          @instance.message({channel: "/foo", message: JSON.stringify { message: "msg-#{i}" } })
        for i in [6..10]
          @instance.message({channel: "/bar", message: JSON.stringify { message: "msg-#{i}" } })

        @instance.unsubscribe("/foo")

        for i in [11..15]
          @instance.message({channel: "/foo", message: JSON.stringify { message: "msg-#{i}" } })
        for i in [16..20]
          @instance.message({channel: "/bar", message: JSON.stringify { message: "msg-#{i}" } })

        expect(@receivedMessages).toEqual(
          {message: "msg-#{i}"} for i in [1,2,3,4,5,6,7,8,9,10,16,17,18,19,20]
        )

  describe "dynamic subscription handling", ->
    it "subscribes & unsubscribes to a channel dynamically", ->
      @instance.connect().then =>
        messages = []

        @instance.message({channel: "/dynamic", message: JSON.stringify { message: "hello 1" }})
        @instance.message({channel: "/dynamic", message: JSON.stringify { message: "hello 2" }})

        expect(messages).toEqual([])

        @instance.subscribe "/dynamic",
          message: (msg) ->
            messages.push(msg)

        @instance.message({channel: "/dynamic", message: JSON.stringify { message: "hello 3" }})
        @instance.message({channel: "/dynamic", message: JSON.stringify { message: "hello 4" }})

        @instance.unsubscribe "/dynamic"

        @instance.message({channel: "/dynamic", message: JSON.stringify { message: "hello 5" }})
        @instance.message({channel: "/dynamic", message: JSON.stringify { message: "hello 6" }})

        expect(messages).toEqual([
          {message: "hello 3"},
          {message: "hello 4"},
        ])
