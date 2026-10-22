sub init()
    m.title = m.top.findNode("title")
    m.value = m.top.findNode("value")
    m.highlight = m.top.findNode("highlight")
    m.accent = m.top.findNode("accent")
end sub

sub onContentChanged()
    content = m.top.itemContent
    if content = invalid then return
    m.title.text = content.title
    if content.shortDescriptionLine1 = "toggle"
        m.value.text = Chr(8249) + "  " + content.description + "  " + Chr(8250)
    else
        m.value.text = content.description
    end if
end sub

sub updateFocus()
    p = m.top.focusPercent
    if not m.top.listHasFocus then p = 0
    m.highlight.opacity = p
    m.accent.opacity = p
    if p > 0.5 then m.title.color = "0xFFFFFFFF" else m.title.color = "0xC8CAD4FF"
end sub
