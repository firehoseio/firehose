if module?.exports?
  global.Firehose ||= {}
else
  window.Firehose ||= {}
