# Helper used to define browser globals that our node app needs
# Defines
# - window
# - document
# - location
# - $

# jQuery dependencies
jsdom = require("jsdom")
global.document = jsdom.jsdom("<html></html>")
global.window = document.defaultView

# this needs to be attached to the jsdom window object to override
# jsdom's internal xmlhttprequest object
window.XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest

# URIjs dependencies

# Set a location so that URIjs behaves correctly
jsdom.changeURL(window, "http://localhost:8080")

# URIjs accesses location via "location.href"
global.location = window.location

# require("jquery") onnly loads the library.
# You need to initialize it with a Window object
global.$ = require "jquery"
$(window)

# Node environments need this, browsers implement it themselves
global.WebSocket = require "ws"

# Current version
module.exports =
  version: require("../package.json").version
