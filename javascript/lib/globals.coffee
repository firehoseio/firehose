# xhr
global.XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest

# jQuery dependencies
jsdom = require("jsdom")
global.document = jsdom.jsdom("<html></html>")
global.window = document.defaultView

# URIjs dependencies

# Set a location so that URIjs behaves correctly
jsdom.changeURL(window, "http://localhost:8080")

# URIjs accesses location via "location.href"
global.location = window.location

# require("jquery") onnly loads the library.
# You need to initialize it with a Window object
global.$ = require "jquery"
$(window)
