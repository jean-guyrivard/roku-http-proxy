sub init()
  top = m.top

  m.dataList = top.findNode("dataList")
  m.layout = top.findNode("layout")
  m.instructions = top.findNode("instructions")
  m.status = top.findNode("status")

  m.layout.update({
    translation: [20, 960],
    itemSpacings: [10]
    layoutDirection: "vert"
  })
  m.dataList.update({
    translation: [50, 150],
    itemComponentName: "VideoModel"
    showRowLabel: [true]
    itemSize: [1820, 440],
    rowItemSize:  [[320, 380]]
    rowItemSpacing: [[20, 20]]
    rowLabelOffset: [0, 10]
    rowFocusAnimationStyle: "fixedFocus"
    vertFocusAnimationStyle: "floatingFocus"
    numRows: 1
  })
  m.instructions.update({
    text: "Press Replay to send request"
  })
  m.status.update({
    text: "Status: Press Replay"
  })

  m.apiNode = m.top.createChild("Node")
  m.apiNode.update({id: "apiNode", request: {subType: "Node"}, response: {subType: "ContentNode"}}, true)
  m.apiNode.observeFieldScoped("response", "onRESTResponse")

  m.restApi = CreateObject("roSGNode", "Task.RestApi")
  m.restApi.proxy = Invalid
  m.restApi.control = "run"

  m.dataList.setFocus(true)
end sub

sub onRESTResponse(event)
  response = event.getData()

  if "TestApi" = response.index
    if Invalid <> response.error
      ?"Response Error", response
    else
      if Invalid <> response.products
        content = CreateObject("roSGNode", "ContentNode")
        row = content.createChild("ContentNode")
        for each product in response.products
          col = row.createChild("ContentNode")
          col.update({
            HDPOSTERURL: product.thumbnail
            title: product.title
          }, true)
        end for

        m.dataList.content = content
      end if
    end if
  end if
end sub

function onKeyEvent(key, press) as Boolean
  handled = false

  if press = true
    if "back" = key
      m.top.exitApplication = true
      handled = true
    else if "replay" = key
      m.dataList.content = CreateObject("roSGNode", "ContentNode")
      if m.restApi.proxy = Invalid
        m.restApi.proxy = {ip: "192.168.11.101", port: 8422}
        m.status.update({
          text: "Status: Proxied"
        })
      else
        m.restApi.proxy = Invalid
        m.status.update({
          text: "Status: Direct (roUrlTransfer)"
        })
      end if

      m.restApi.request = [{
        index:"TestApi",
        method: "GET",
        uri: "https://dummyjson.com/products/search?q=Laptop",
        requestor: m.apiNode
      }]
    end if
  end if

  return handled
end function