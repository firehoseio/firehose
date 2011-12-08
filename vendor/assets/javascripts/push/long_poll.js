(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  this.module("Push", function() {
    return this.LongPoll = (function() {
      __extends(LongPoll, this.Transport);
      LongPoll.ieSupported = function() {
        return $.browser.msie && parseInt($.browser.version) > 7 && window.XDomainRequest;
      };
      LongPoll.supported = function() {
        return $.support.cors || LongPoll.ieSupported();
      };
      function LongPoll(args) {
        this._error = __bind(this._error, this);
        this._success = __bind(this._success, this);
        this._request = __bind(this._request, this);
        this.registerIETransport = __bind(this.registerIETransport, this);
        this.LongPoll = __bind(this.LongPoll, this);
        this.LongPoll = __bind(this.LongPoll, this);        LongPoll.__super__.constructor.call(this, args);
        this._lagTime = 5000;
        this._timeout = this.options.timeout + this._lagTime;
        this._dataType = "json";
        this._offlineTimer;
        this._okInterval = 0;
        this.registerIETransport();
      }
      LongPoll.prototype.registerIETransport = function() {
        if (LongPoll.ieSupported()) {
          $.ajaxTransport('json', function(options, orignalOptions, jqXhr) {
            var xdr;
            xdr = null;
            return {
              send: function(_, callback) {
                xdr = new XDomainRequest();
                xdr.onload = function() {
                  var statusCode;
                  statusCode = xdr.responseText.length > 0 ? 200 : 204;
                  return callback(statusCode, 'success', {
                    text: xdr.responseText
                  });
                };
                xdr.onerror = xdr.ontimeout = function() {
                  return callback(400, 'failed', {
                    text: xdr.responseText
                  });
                };
                xdr.open(options.type, options.url);
                return xdr.send(options.data);
              },
              abort: function() {
                if (xdr) {
                  xdr.onerror = $.noop();
                  return xdr.abort();
                }
              }
            };
          });
          return $.support.cors = true;
        }
      };
      LongPoll.prototype._request = function() {
        return $.ajax(this.url["longpoll"], {
          crossDomain: true,
          cache: false,
          dataType: this._dataType,
          data: this.params,
          timeout: this._timeout,
          success: this._success,
          error: this._error
        });
      };
      LongPoll.prototype._success = function(data, status, jqXhr) {
        if (jqXhr.status === 204) {
          return this.connect(this._okInterval);
        } else {
          this.onMessage(data);
          return this.connect(this._okInterval);
        }
      };
      LongPoll.prototype._error = function(jqXhr, status, error) {
        clearTimeout(this._offlineTimer);
        this.onDisconnected();
        this._offlineTimer = setTimeout(this.onConnected, this._errorInterval + this._lagTime);
        return this.connect(this._errorInterval);
      };
      return LongPoll;
    }).call(this);
  });
}).call(this);
