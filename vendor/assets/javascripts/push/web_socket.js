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
    return this.WebSocket = (function() {
      __extends(WebSocket, this.Transport);
      WebSocket.flashSupported = function() {
        return $.browser.msie;
      };
      WebSocket.supported = function() {
        return window.WebSocket || (window["MozWebSocket"] && window.MozWebSocket) || WebSocket.flashSupported();
      };
      function WebSocket(args) {
        this._error = __bind(this._error, this);
        this._close = __bind(this._close, this);
        this._message = __bind(this._message, this);
        this._request = __bind(this._request, this);
        this.WebSocket = __bind(this.WebSocket, this);
        this.WebSocket = __bind(this.WebSocket, this);        WebSocket.__super__.constructor.call(this, args);
        WebSocket.__swfLocation = "push/javascripts/flash/WebSocketMain.swf";
        if (window["MozWebSocket"] && window.MozWebSocket) {
          window.WebSocket = window.MozWebSocket;
        }
      }
      WebSocket.prototype._request = function() {
        this.socket = new window.WebSocket(this.url["websocket"] + "?" + $.param(this.params));
        this.socket.onopen = this._open;
        this.socket.onclose = this._close;
        this.socket.onerror = this._error;
        return this.socket.onmessage = this._message;
      };
      WebSocket.prototype._message = function(event) {
        try {
          return this.onMessage($.parseJSON(event.data));
        } catch (e) {

        }
      };
      WebSocket.prototype._close = function(event) {
        if (!event || (event && !event.wasClean)) {
          return this._error(event);
        }
      };
      WebSocket.prototype._error = function(event) {
        if (this.socket) {
          this.socket.onopen = null;
          this.socket.onclose = null;
          this.socket.onerror = null;
          this.socket.onmessage = null;
          this.socket.close();
          delete this.socket;
        }
        return WebSocket.__super__._error.apply(this, arguments);
      };
      return WebSocket;
    }).call(this);
  });
}).call(this);
