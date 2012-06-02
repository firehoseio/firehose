_super = jQuery.ajaxSettings.xhr

jQuery.ajaxSettings.xhr = ->
  xhr = _super()
  getAllResponseHeaders = xhr.getAllResponseHeaders
  xhr.getAllResponseHeaders = ->
    allHeaders = getAllResponseHeaders.call(xhr)
    return allHeaders if allHeaders

    allHeaders = ""
    for headerName in [ "Cache-Control", "Content-Language", "Content-Type", "Expires", "Last-Modified", "Pragma" ]
      do (headerName) ->
        allHeaders += headerName + ": " + xhr.getResponseHeader(headerName) + "\n"  if xhr.getResponseHeader(headerName)

    allHeaders
  xhr
