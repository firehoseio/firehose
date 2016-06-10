describe 'Firehose.LongPollTransport', ->
  beforeEach ->
    @klass    = Firehose.LongPollTransport
    @instance = new @klass()

  afterEach -> @instance.stop()

  #= Specs ===

  it '.ieSupported returns a Boolean', ->
    expect( typeof @klass.ieSupported() ).toBe 'boolean'

  it '.supported returns a Boolean', ->
    expect( typeof @klass.supported() ).toBe 'boolean'

  describe '#stop', ->
    beforeEach ->
      @instance._lastRequest     = $.ajax()
      @instance._lastPingRequest = $.ajax()

    it 'aborts the last request', ->
      sinon.spy @instance._lastRequest, 'abort'
      Object.freeze @instance # Prevents the delete call from modifying the request object, so we can verify the call
      @instance.stop()
      expect( @instance._lastRequest.abort.called ).toBe true

    it 'deletes reference to the last request', ->
      @instance.stop()
      expect( @instance._lastRequest? ).toBe false

    it 'aborts the last ping request', ->
      sinon.spy @instance._lastPingRequest, 'abort'
      Object.freeze @instance # Prevents the delete call from modifying the request object, so we can verify the call
      @instance.stop()
      expect( @instance._lastPingRequest.abort.called ).toBe true

    it 'deletes reference to the last ping request', ->
      @instance.stop()
      expect( @instance._lastPingRequest? ).toBe false

  describe 'callbacks', ->
    for callback in ['_request','_success','_ping','_error']
      it "has a #{callback} callback function", ->
        expect( @instance[callback] ).toEqual jasmine.any Function
