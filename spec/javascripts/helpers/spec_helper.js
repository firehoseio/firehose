require( '/javascripts/vendor/json2.js'        );
require( '/javascripts/vendor/sinon-1.7.3.js'  );
require( '/javascripts/firehose/base.js'       );
require( '/javascripts/firehose/transport.js'  );
require( '/javascripts/firehose/web_socket.js' );
require( '/javascripts/firehose/long_poll.js'  );
require( '/javascripts/firehose/consumer.js'   );

//= Mock out jQuery / Zepto calls
window.$ = {
  ajaxSettings : {
    xhr : function(){
      return { withCredentials : true }
    }
  },
  supported : { }
};