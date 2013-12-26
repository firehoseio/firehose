describe 'Firehose.Transport', ->
  beforeEach ->
    @klass    = Firehose.Transport
    @instance = new @klass()

  it '.supported returns false', -> expect( @klass.supported() ).toBe false
  it '.name throws error',       -> expect( -> @instance.name  ).toThrow()
  it '.stop throws error',       -> expect( -> @instance.stop  ).toThrow()

  describe 'constructor', ->
    xit 'sets the @config object'
    xit 'sets a retry delay'

  describe '#connect', ->
    xit 'schedules @_request after the given delay'
    it 'returns itself', -> expect( @instance.connect() ).toBe @instance


