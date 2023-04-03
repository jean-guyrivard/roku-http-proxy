sub init()
  top = m.top

  m.poster = top.findNode("poster")
  m.title = top.findNode("title")

  m.poster.update({
    width: 320
    loadwidth: 320
    height: 180
    loadheight: 180
    loadDisplayMode: "limitSize"
  })
  m.title.update({
    translation: [0, 190]
    width: 320
    wrap: true
  })

  top.observeFieldScoped("itemContent", "onItemContentChanged")
end sub

sub onItemContentChanged(event)
  newContent = event.getData()

  m.poster.uri = newContent.HDPOSTERURL
  m.title.text = newContent.title

end sub