describe 'Firehose.Transport', ->
  beforeEach ->
    @klass    = Firehose.Transport
    @instance = new @klass()

  it '.supported returns false', -> expect( @klass.supported() ).toBe false
  it '.name throws error',       -> expect( -> @instance.name  ).toThrow()
  it '.stop throws error',       -> expect( -> @instance.stop  ).toThrow()

  describe 'constructor', ->
    it 'returns an instance',     -> expect( @instance             ).toEqual jasmine.any @klass
    it 'sets the @config object', -> expect( @instance.config      ).toEqual jasmine.any Object
    it 'sets a retry delay',      -> expect( @instance._retryDelay ).toEqual jasmine.any Number

  describe '#connect', ->
    describe 'when given a 500 delay', ->
      beforeEach ->
        @clock = sinon.useFakeTimers()
        sinon.stub @instance, '_request'
        @instance.connect 500

      afterEach -> @clock.restore()

      it 'does not call _request before the given delay', ->
        @clock.tick 499
        expect( @instance._request.called ).toBe false

      it 'calls _request after the given delay', ->
        @clock.tick 600
        expect( @instance._request.called ).toBe true

  describe '_checkDroppedMessages', ->
    it 'calls the dropped callback if the client missed messages', ->
      droppedSequences = []
      @instance = new @klass
        dropped: (sequence) ->
          droppedSequences.push(sequence)

      @instance._lastMessageSequence = 100
      @instance._checkDroppedMessages({last_sequence: null})
      expect(droppedSequences).toEqual []

      @instance._lastMessageSequence = null
      @instance._checkDroppedMessages({last_sequence: 100})
      expect(droppedSequences).toEqual []

      @instance._checkDroppedMessages({last_sequence: null})
      expect(droppedSequences).toEqual []

      @instance._lastMessageSequence = 100
      @instance._checkDroppedMessages({last_sequence: undefined})
      expect(droppedSequences).toEqual []

      @instance._lastMessageSequence = undefined
      @instance._checkDroppedMessages({last_sequence: 100})
      expect(droppedSequences).toEqual []

      @instance._lastMessageSequence = 11
      @instance._checkDroppedMessages({last_sequence: 10})
      expect(droppedSequences).toEqual []

      @instance._lastMessageSequence = 15
      @instance._checkDroppedMessages({last_sequence: 10})
      expect(droppedSequences).toEqual [11, 12, 13, 14]

      @instance._lastMessageSequence = 20
      @instance._checkDroppedMessages({last_sequence: 15})
      expect(droppedSequences).toEqual [11, 12, 13, 14, 16, 17, 18, 19]

  describe '_checkMultiplexedDroppedMessages', ->
    it 'calls the dropped callback if the client missed messages', ->
      droppedA = []
      droppedB = []

      @instance = new Firehose.MultiplexedWebSocket
        channels:
          "a":
            dropped: (seq) ->
              droppedA.push seq
          "b":
            dropped: (seq) ->
              droppedB.push seq

      @instance._lastMessageSequence =
        "a": null
        "b": null

      @instance._checkMultiplexedDroppedMessages({channel: "a", last_sequence: null})
      expect(droppedA).toEqual []

      @instance._checkMultiplexedDroppedMessages({channel: "a", last_sequence: 100})
      expect(droppedA).toEqual []

      @instance._checkMultiplexedDroppedMessages({channel: "a", last_sequence: null})
      expect(droppedA).toEqual []

      @instance._lastMessageSequence["a"] = 100
      @instance._checkMultiplexedDroppedMessages({channel: "a", last_sequence: undefined})
      expect(droppedA).toEqual []

      @instance._lastMessageSequence["a"] = undefined
      @instance._checkMultiplexedDroppedMessages({channel: "a", last_sequence: 100})
      expect(droppedA).toEqual []

      @instance._lastMessageSequence["a"] = 11
      @instance._checkMultiplexedDroppedMessages({channel: "a", last_sequence: 10})
      expect(droppedA).toEqual []

      @instance._lastMessageSequence["b"] = 15
      @instance._checkMultiplexedDroppedMessages({channel: "b", last_sequence: 10})
      expect(droppedA).toEqual []
      expect(droppedB).toEqual [11, 12, 13, 14]

      @instance._lastMessageSequence["a"] = 20
      @instance._checkMultiplexedDroppedMessages({channel: "a", last_sequence: 15})
      expect(droppedA).toEqual [16, 17, 18, 19]

      @instance._lastMessageSequence["b"] = 20
      @instance._checkMultiplexedDroppedMessages({channel: "b", last_sequence: 15})
      expect(droppedA).toEqual [16, 17, 18, 19]
      expect(droppedB).toEqual [11, 12, 13, 14, 16, 17, 18, 19]
