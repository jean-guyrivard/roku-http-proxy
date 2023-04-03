function getProxiedUrlTransfer(proxy)
  if Invalid = proxy?.port
    proxy.port = 80
  end if

  sendAddress = CreateObject("roSocketAddress")
  sendAddress.SetAddress(proxy.ip + ":" + proxy.port.toStr())

  devInfo = CreateObject("roDeviceInfo")
  osVersion = devInfo.getOSVersion()

  return {
    socket: Invalid
    sendAddress: sendAddress
    urlTransfer: CreateObject("roUrlTransfer")
    host: Invalid
    port: Invalid
    url: Invalid
    proxyIp: proxy.ip
    proxyPort: proxy.port
    stage: "header"
    requestType: Invalid
    defaultHeaders: {
      "content-type": "application/x-www-form-urlencoded"
      ' "accept-encoding": "deflate, gzip"
      "accept": "*/*"
      "user-agent": "Roku/DVP-" + osVersion.major + "." + osVersion.minor + " (" + osVersion.major + "." + osVersion.minor + "." + osVersion.revision + "." + osVersion.build + ")"
      "Connection": "close"
    }
    headers: {}
    body: ""
    responseHeaders: {}
    responseBody: CreateObject("roByteArray")
    messagePort: Invalid
    responseCode: -1
    initSocket: sub()
      m.socket = CreateObject("roStreamSocket")
      m.socket.NotifyReadable(true)
      m.socket.NotifyWritable(true)
    end sub
    setPort: sub(messagePort)
      m.messagePort = messagePort
    end sub
    setHeaders: sub(headers)
      m.headers.append(headers)
    end sub
    setUrl: sub(url)
      regEx = CreateObject("roRegEx", "^https?:\/\/([a-z0-9_\-.]+)(?:\:([0-9]+))?", "i")
      match = regEx.match(url)
      m.host = match[1]
      m.port = match[2]
      m.url = url
    end sub
    getUrl: function()
      return m.url
    end function
    GetIdentity: function()
      return m.socket.getID()
    end function
    escape: function(inStr)
      return m.urlTransfer.escape(inStr)
    end function
    setRequest: sub(request)
      m.requestType = request
    end sub
    enableEncodings: sub(enabled)
    end sub
    SetCertificatesFile: sub(certFile)
    end sub
    SetHttpVersion: sub(version)
    end sub
    getIdentity: function()
      if Invalid = m.socket
        m.initSocket()
      end if

      return m.socket.getID()
    end function
    getResponseCode: function()
      return m.responseCode
    end function
    getToString: function()
      ?"Proxy: getToString"
      return ""
    end function
    postFromString: function(body)
      ?"Proxy: postFromString"
      return ""
    end function
    AsyncGetToString: function()
      ?"Proxy: AsyncGetToString"
      if Invalid = m.requestType
        m.requestType = "GET"
      end if
      return m.sendRequest()
    end function
    AsyncPostFromString: function(body)
      ?"Proxy: AsyncPostFromString"
      if Invalid = m.requestType
        m.requestType = "POST"
      end if
      m.body = body
      return m.sendRequest()
    end function
    GetString: function()
      if m.responseHeaders["Content-Encoding"] = Invalid AND m.responseHeaders["Transfer-Encoding"] = Invalid
        return m.responseBody.ToAsciiString()
      else if m.responseHeaders["Transfer-Encoding"] = "chunked"
        returnString = ""

        responseData = m.responseBody.ToAsciiString()

        index = 0
        while 1
          crLF = responseData.instr(index, chr(13) + chr(10))
          if CRLF > 0
            chunkSizeStr = responseData.mid(index, crLf - index)
            chunkSize = val(chunkSizeStr, 16)
          else
            chunkSize = 0
          end if
          if chunkSize = 0
            exit while
          end if

          index += chunkSizeStr.len() + 2

          chunk = responseData.mid(index, chunkSize)
          returnString += chunk

          index += chunkSize + 2
        end while

        return returnString
      else
        ?"Not implemented Body Encoding: " + m.responseHeaders["Content-Encoding"], m.responseHeaders["Transfer-Encoding"], m.responseHeaders["content-length"], m.responseBody.count()
        return Invalid
      end if
    end function
    sendRequest: function()
      if Invalid = m.socket
        m.initSocket()
      end if
      m.socket.setSendToAddress(m.sendAddress)

      m.socket.setMessagePort(m.messagePort)

      m.responseHeaders = {}
      m.responseBody.clear()
      m.stage = "header"

      headers = {}
      headers.append(m.defaultHeaders)
      headers.append(m.headers)

      if m.socket.connect()
        ba=CreateObject("roByteArray")
        requestData = ""
        requestData += m.requestType + " " + m.url + " HTTP/1.1" + chr(13) + chr(10)

        requestData += "Host: " + m.host
        if Invalid <> m.port
          requestData += ":" + m.port
        end if
        requestData += chr(13) + chr(10)

        for each header in headers.Items()
          if header.value <> ""
            requestData += header.key + ": " + header.value + chr(13) + chr(10)
          end if
        end for
        if Invalid = headers["Content-Type"]
          requestData += "Content-Type: application/json" + chr(13) + chr(10)
        end if
        requestData += "Content-Length:" + m.body.len().toStr() + chr(13) + chr(10)

        if m.body <> ""
          requestData += chr(13) + chr(10)
          requestData += m.body + chr(13) + chr(10)
        end if

        requestData += chr(13) + chr(10) + chr(13) + chr(10)

        m.pendingRequest = requestData

        return true
      else
        return false
      end if
    end function
  }
end function

function proxyParseResponse(request)
  socket = request.socket

  if Invalid <> request.pendingRequest AND socket.isWritable()
    socket.SendStr(request.pendingRequest)
    request.pendingRequest = Invalid
  else if socket.isReadable()
    buffer = CreateObject("roByteArray")
    buffer[1024] = 0
    received = socket.receive(buffer, 0, 1024)
    buffer[received] = 0
    if 0 = received
      request.stage = "complete"
      socket.close()

      request.headers = {}
      request.body = ""
      request.responseCode = -1
      request.socket = Invalid
      return true
    else
      data = buffer.ToAsciiString()
      if request.stage = "header" AND data.startsWith("HTTP/")
        parts = data.split(chr(13) + chr(10) + chr(13) + chr(10))

        httpRegex = CreateObject("roRegEx", "^HTTP\/([0-9.]*) ([0-9]{3}) ([\s\S]+)$", "i")
        matches = httpRegex.match(parts[0])
        request.responseCode = matches[2].toInt()

        headers = parts[0].split(chr(13) + chr(10))
        headers.delete(0)
        for each header in headers
          keyValue = header.split(": ")
          if keyValue[1] <> Invalid
            request.responseHeaders.addReplace(keyValue[0], keyValue[1])
          end if
        end for
        if parts[1] <> Invalid AND parts[1] <> ""
          if Invalid = request.responseHeaders["Transfer-Encoding"]
            for i = parts[0].len()+4 to received-1
              request.responseBody.push(buffer[i])
            end for
          end if
        end if
        request.stage = "body"
      else if request.stage = "body"
        for i = 0 to received-1
          request.responseBody.push(buffer[i])
        end for
       end if
    end if
  end if

  return false
end function

sub processChunkedBuffer(startIndex)
end sub