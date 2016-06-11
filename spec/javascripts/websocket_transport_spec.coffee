describe 'Firehose.WebSocketTransport', ->
  beforeEach ->
    @klass    = Firehose.WebSocketTransport
    @instance = new @klass(uri: 'ws://localhost/test')

  #= Specs ===

  it '.name returns a string',         -> expect( @instance.name() ).toEqual jasmine.any String
  it '.ieSupported returns a Boolean', -> expect( typeof @klass.ieSupported() ).toBe 'boolean'
  it '.supported returns a Boolean',   -> expect( typeof @klass.supported()   ).toBe 'boolean'

  describe 'callbacks', ->
    for callback in ['_request','_success','_ping','_error']
      it "has a #{callback} callback function", ->
        expect( @instance[callback] ).toEqual jasmine.any Function

  describe '#stop', ->
    beforeEach ->
      # call _request directly so we don't have to wait for the setTimeout
      # call to call _request in the next event loop iteration
      @instance._request()
      sinon.spy @instance.socket, 'close'
      Object.freeze @instance # stop _cleanUp method deleting the socket

    it 'closes the socket', ->
      @instance.stop()
      expect( @instance.socket.close.called ).toBe true
