describe 'Firehose.LongPoll', ->
  beforeEach ->
    @klass    = Firehose.LongPoll
    @instance = new @klass()

  afterEach -> @instance.stop()


  it '.ieSupported returns a Boolean', ->
    expect( typeof @klass.ieSupported() ).toBe 'boolean'

  it '.supported returns a Boolean', ->
    expect( typeof @klass.supported() ).toBe 'boolean'

  describe '#stop', ->
    xit 'aborts the last request'
    xit 'aborts the last ping request'

  describe 'callbacks', ->
    for callback in ['_request','_success','_ping','_error']
      it "has a #{callback} callback function", ->
        expect( @instance[callback] ).toEqual jasmine.any Function
