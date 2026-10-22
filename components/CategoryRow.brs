sub init()
    m.name = m.top.findNode("name")
    m.count = m.top.findNode("count")
    m.highlight = m.top.findNode("highlight")
    m.accent = m.top.findNode("accent")
end sub

' Row titles look like "Sports  (101)": show the name and the count separately.
sub onContentChanged()
    content = m.top.itemContent
    if content = invalid then return
    title = content.title
    split = Instr(1, title, "  (")
    if split > 0
        m.name.text = Left(title, split - 1)
        m.count.text = Mid(title, split + 3).Replace(")", "")
    else
        m.name.text = title
        m.count.text = ""
    end if
end sub

sub updateFocus()
    p = m.top.focusPercent
    if not m.top.listHasFocus then p = p * 0.45
    m.highlight.opacity = p
    m.accent.opacity = p
    if p > 0.4 then m.name.color = "0xFFFFFFFF" else m.name.color = "0xC8CAD4FF"
end sub
