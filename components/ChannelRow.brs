sub init()
    m.logo = m.top.findNode("logo")
    m.title = m.top.findNode("title")
    m.highlight = m.top.findNode("highlight")
    m.accent = m.top.findNode("accent")
end sub

sub onContentChanged()
    content = m.top.itemContent
    if content = invalid then return
    m.logo.uri = content.HDPosterUrl
    m.title.text = content.title
end sub

' focusPercent animates 0..1 as the list's focus moves, so the highlight fades smoothly.
sub updateFocus()
    p = m.top.focusPercent
    if not m.top.listHasFocus then p = p * 0.35
    m.highlight.opacity = p
    m.accent.opacity = p
    if p > 0.5 then m.title.color = "0xFFFFFFFF" else m.title.color = "0xC8CAD4FF"
end sub
