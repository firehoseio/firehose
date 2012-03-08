(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  this.module("Push", function() {
    return this.Transport = (function() {

      Transport.supported = function() {
        return false;
      };

      function Transport(args) {
        this._close = __bind(this._close, this);
        this._open = __bind(this._open, this);
        this._error = __bind(this._error, this);
        this._request = __bind(this._request, this);
        this.connect = __bind(this.connect, this);        this._errorInterval = 5000;
      }

      Transport.prototype.connected = function(onConnected) {
        this.onConnected = onConnected;
        return this;
      };

      Transport.prototype.disconnected = function(onDisconnected) {
        this.onDisconnected = onDisconnected;
        return this;
      };

      Transport.prototype.message = function(onMessage) {
        this.onMessage = onMessage;
        return this;
      };

      Transport.prototype.error = function(onError) {
        this.onError = onError;
        return this;
      };

      Transport.prototype.url = function(url) {
        this.url = url;
        return this;
      };

      Transport.prototype.params = function(params) {
        this.params = params;
        return this;
      };

      Transport.prototype.options = function(options) {
        this.options = options;
        return this;
      };

      Transport.prototype.connect = function(delay) {
        var _this = this;
        if (delay == null) delay = 0;
        return setTimeout(function() {
          return _this._request();
        }, delay);
      };

      Transport.prototype._request = function() {};

      Transport.prototype._error = function(event) {
        this.onDisconnected();
        return this.connect(this._errorInterval);
      };

      Transport.prototype._open = function(event) {
        return this.onConnected();
      };

      Transport.prototype._close = function(event) {
        return this.onDisconnected();
      };

      return Transport;

    }).call(this);
  });

}).call(this);
