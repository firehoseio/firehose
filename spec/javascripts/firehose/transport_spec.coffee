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
    it 'returns itself', -> expect( @instance.connect() ).toBe @instance

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