describe 'Firehose.Consumer', ->
  beforeEach ->
    @klass    = Firehose.Consumer
    @instance = new @klass uri: 'test_uri', okInterval: 9999 # Stop crazy ajax loops during tests


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
        sinon.spy @instance.transport, 'stop'

      it 'calls stop once on @transport', ->
        @instance.stop()
        expect( @instance.transport.stop.calledOnce ).toBe true

      it 'stops the upgrade timeout', ->
        @instance.stop()
        expect( @instance.upgradeTimeout? ).toBe false

