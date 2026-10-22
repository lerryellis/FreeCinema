sub init()
    m.list = m.top.findNode("list")
    m.list.observeField("itemSelected", "onItemSelected")
end sub

sub onContent()
    m.list.content = m.top.content
end sub

sub onActive()
    if m.top.active
        m.list.jumpToItem = 0
        m.list.setFocus(true)
    end if
end sub

function currentRow() as Dynamic
    if m.top.content = invalid then return invalid
    return m.top.content.getChild(m.list.itemFocused)
end function

sub onItemSelected()
    row = m.top.content.getChild(m.list.itemSelected)
    if row = invalid then return
    if row.shortDescriptionLine1 = "toggle"
        m.top.cycle = { index: m.list.itemSelected, delta: 1 }
    else
        m.top.selected = m.list.itemSelected
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return true
    if key = "left" or key = "right"
        row = currentRow()
        if row <> invalid and row.shortDescriptionLine1 = "toggle"
            delta = 1
            if key = "left" then delta = -1
            m.top.cycle = { index: m.list.itemFocused, delta: delta }
        end if
        return true
    end if
    if key = "back" or key = "options"
        m.top.closed = true
        return true
    end if
    ' Swallow everything else so keys don't leak to the scene behind the menu.
    return key <> "up" and key <> "down" and key <> "OK"
end function
