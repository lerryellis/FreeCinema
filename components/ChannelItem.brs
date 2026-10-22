sub init()
    m.logo = m.top.findNode("logo")
    m.title = m.top.findNode("title")
end sub

sub onContentChanged()
    content = m.top.itemContent
    if content = invalid then return
    m.logo.uri = content.HDPosterUrl
    m.title.text = content.title
end sub
