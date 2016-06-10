describe 'Firehose namespace', ->
  it 'exists', -> expect( window?.Firehose || global.Firehose ).toEqual jasmine.any Object
