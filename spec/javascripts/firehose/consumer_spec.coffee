describe 'Firehose.Consumer', ->
  beforeEach ->
    @klass    = Firehose.Consumer
    @instance = new @klass uri: 'test_uri', okInterval: 9999 # Stop crazy ajax loops during tests

  # afterEach -> @instance.stop() # FIXME Stop doesn't seem to work here... added the high okInterval above as temporary remedy


  #= Specs ===

  describe 'new instance', ->
    describe '@config', ->
      beforeEach -> @subj = @instance.config

      for callback in ['message','error','connected','disconnected','failed']
        it "has a .#{callback} function", ->
          expect( @subj[callback] ).toEqual jasmine.any Function

      it 'has a params object', ->
        expect( @subj.params ).toEqual jasmine.any Object

      it 'has a parse function', ->
        expect( @subj.parse ).toEqual jasmine.any Function

  describe '#connect', ->
    it 'runs without error', -> @instance.connect()

    describe 'after #connect called', ->
      beforeEach -> @instance.connect()

      it 'creates a @transport instance', ->
        expect( @instance.transport ).toEqual jasmine.any Firehose.Transport

  describe '#stop', ->
    describe 'when .connect called earlier', ->
      beforeEach ->
        @instance.connect()
        spyOn @instance.transport, 'stop'

      it 'calls stop on @transport', ->
        @instance.stop()
        expect( @instance.transport.stop ).toHaveBeenCalled()

      xit 'stops the upgrade timeout'
