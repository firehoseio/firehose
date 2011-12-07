(function() {
  this.module("Push", function() {
    return this.Client = (function() {
      function Client(args) {
        var transport;
        this.transports = ['WebSocket', 'LongPoll'];
        transport = _.detect(this.transports, function(transport) {
          return Push[transport].supported();
        });
        return new Push[transport](args);
      }
      return Client;
    })();
  });
}).call(this);
