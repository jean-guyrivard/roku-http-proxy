sub main(externalParams)
  screen = CreateObject("roSGScreen")
  port = CreateObject("roMessagePort")
  screen.setMessagePort(port)
  m.global = screen.getGlobalNode()

  m.global.update({
    deeplink: externalParams
  }, true)
  'Create Main Scene
  scene = screen.CreateScene("MainScene")
  screen.show() ' vscode_rale_tracker_entry

  'Watch field to exit application
  scene.observeField("exitApplication", port)

  while(true)
    msg = wait(0, port)
    msgType = type(msg)
    if invalid <> msg
      if "roSGNodeEvent" = msgType
        msgField = msg.GetField()
        msgData = msg.getData()
        if "exitApplication" = msgField AND true = msgData then return
      end if
    end if
  end while
end sub