sub init()
  m.top.functionName = "restApiTaskFunction"

  m.messagePort = createObject("roMessagePort")
  m.top.observeFieldScoped("proxy", m.messagePort)
  m.top.observeFieldScoped("request", m.messagePort)
end sub

sub restApiTaskFunction()
  manifest = m.global.manifest
  m.device = createObject("roDeviceInfo")

  m.requestQueue = {}
  m.proxy = Invalid

  while(true)
    msg = wait(0, m.messagePort)
    if msg = invalid
      ' Handle Timeouts
    else if "roUrlEvent" = type(msg)
      identity = msg.GetSourceIdentity().toStr()
      requestData = m.requestQueue[identity]
      code = msg.GetResponseCode()
      response = msg.getString()
      headers = msg.getResponseHeaders()

      parseResponse(identity, requestData, code, headers, response)
    else if "roSGNodeEvent" = type(msg)
      if "request" = msg.getField()
        requests = msg.getData()

        for each request in requests
          newResponseQueue = createObject("roSGNode", "Node")
          newResponseQueue.update({ requestCount: 1 }, true)

          createNewRequest(request, newResponseQueue)
        end for
      else if "proxy" = msg.getField()
        m.proxy = msg.getData()
      end if
    else if "roSocketEvent" = type(msg)
      identity = msg.GetSocketID().toStr()
      requestData = m.requestQueue[identity]
      ready = proxyParseResponse(requestData.urlTransfer)

      if ready = true
        responseData = requestData.urlTransfer
        response = responseData.getString()
        parseResponse(identity, requestData, 200, responseData.responseHeaders, response)
      end if
    end if
  end while
end sub

sub createNewRequest(params, masterNode, target = invalid)
  newUrlTransfer = createUrlTransfer()
  newUrlTransfer.setPort(m.messagePort)

  if Invalid <> params.username AND Invalid <> params.password
    auth = CreateObject("roByteArray")
    auth.fromAsciiString(params.username + ":" + params.password)

    newUrlTransfer.setHeaders({
      "Authorization": "Basic " + auth.toBase64String()
    })
  else
    newUrlTransfer.setHeaders({
      "Authorization": ""
    })
  end if
  if Invalid <> params.headers
    newUrlTransfer.setHeaders(params.headers)
  end if
  newUrlTransfer.setUrl("")

  requestParse(params, newUrlTransfer)

  params.masterNode = masterNode
  timer = createObject("roTimespan")

  m.requestQueue[newUrlTransfer.GetIdentity().toStr()] = { urlTransfer: newUrlTransfer, responseQueue: masterNode, targetNode: target, params: params, timer: timer }
end sub

function createUrlTransfer()
  if Invalid <> m.proxy
    newUrlTransfer = getProxiedUrlTransfer(m.proxy)
  else
    newUrlTransfer = createObject("roUrlTransfer")
    newUrlTransfer.EnableEncodings(true)
    newUrlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    newUrlTransfer.InitClientCertificates()
    newUrlTransfer.RetainBodyOnError(true)
  end if

  return newUrlTransfer
end function

function requestParse(params, urlTransfer)
  method = params.method

  queryString = formatQueryString(urlTransfer, params.queryParams)

  if queryString <> ""
    uri = params.uri + "?" + queryString
  else
    uri = params.uri
  end if

  urlTransfer.setUrl(uri)

  response = invalid
  if invalid <> params.isSync and true = params.isSync
    urlTransfer.setRequest(method)
    if "GET" = method
      response = urlTransfer.getToString()
    else if "POST" = method
      body = params.body
      if invalid = body
        body = ""
      end if
      response = urlTransfer.postFromString(body)
    else
      response = urlTransfer.getToString()
    end if
  else
    urlTransfer.setRequest(method)
    body = params.body
    if invalid = body
      body = ""
    end if
    if (not urlTransfer.AsyncPostFromString(body))
    end if
  end if

  return response
end function

function formatQueryString(urlTransfer, params, encode = true)
  queryString = ""

  if Invalid <> urlTransfer AND Invalid <> params
    for each param in params.Items()
      if "" <> queryString
        queryString = queryString + "&"
      end if

      valueType = type(param.value)
      if "String" = valueType OR "roString" = valueType
        if true = encode
          value = urlTransfer.escape(param.value)
        else
          value = param.value
        end if
      else if "roArray" = valueType
        value = FormatJSON(param.value)
      else if "Invalid" = valueType
        value = ""
      else
        value = param.value.toStr()
      end if

      queryString = queryString + param.key + "=" + value
    end for
  end if

  return queryString
end function

sub parseResponse(identity, requestData, code, headers, response)
  if 200 <= code and 300 > code
    if invalid = requestData.error then requestData.error = []
    ' requestData.error.push({ code: code, msg: msg.getFailureReason() })
  end if
  requestData.responseQueue.requestCount--

  if invalid <> headers["content-type"] 'ignore-warning
    if - 1 <> headers["content-type"].inStr("application/xml") 'ignore-warning
      contentType = "xml"
    else if - 1 <> headers["content-type"].inStr("json") 'ignore-warning
      contentType = "json"
    else if - 1 <> headers["content-type"].inStr("text/html") 'ignore-warning
      contentType = "html"
    else if - 1 <> headers["content-type"].inStr("text/vtt") 'ignore-warning
      contentType = "vtt"
    else
      contentType = "text"
    end if
  else
    contentType = "json"
  end if

  if "" <> response
    if "json" = contentType
      responseData = parseJSON(response)
    else if "xml" = contentType
      responseData = CreateObject("roXMLElement")
      responseData.parse(response)
    else if "html" = contentType
      responseData = response
    else
      responseData = {text: response}
    end if
  else
    responseData = invalid
  end if

  response = formatResponse(requestData, responseData, headers, code)

  if invalid <> response
    requestData.responseQueue.appendChild(response.node)
  end if

  if 0 = requestData.responseQueue.requestCount
    target = requestData.params.requestor
    if invalid <> target
      target.update({ request: requestData.params, response: requestData.responseQueue.getChild(0), error: requestData.error }, true)
    end if
  end if

  m.requestQueue.delete(identity)
end sub

function formatResponse(requestData, responseData, headers, code)
  callType = requestData.params.callType
  formatedItems = Invalid

  success = false
  if 200 <= code AND 300 > code
    success = true
  end if

  node = CreateObject("roSGNode", "ContentNode")

  node.update({
    index:requestData.params.index
  }, true)

  if Invalid <> responseData AND Invalid <> requestData AND Invalid <> requestData.params
    node.update(responseData, true)
  end if

  formatedItems = {node:node}

  return formatedItems
end function