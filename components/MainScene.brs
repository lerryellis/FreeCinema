sub init()
    m.rowList = m.top.findNode("rowList")
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("status")
    m.hint = m.top.findNode("hint")

    m.rowList.observeField("rowItemSelected", "onItemSelected")
    m.rowList.observeField("rowItemFocused", "updateHint")
    m.video.observeField("state", "onVideoState")

    m.channels = []
    m.allContent = invalid
    m.searchActive = false
    m.task = invalid
    m.channelByUrl = {}
    m.rowNames = []
    loadFavorites()

    loadPlaylist()
    showQualityPicker()
end sub

' ---------- Playlist loading ----------

function getPlaylistUrl() as String
    sec = CreateObject("roRegistrySection", "FreeCinema")
    if sec.Exists("playlistUrl") then return sec.Read("playlistUrl")
    return DefaultPlaylistUrl()
end function

sub savePlaylistUrl(url as String)
    sec = CreateObject("roRegistrySection", "FreeCinema")
    sec.Write("playlistUrl", url)
    sec.Flush()
end sub

function getCountry() as String
    sec = CreateObject("roRegistrySection", "FreeCinema")
    if sec.Exists("country") then return sec.Read("country")
    return DefaultCountry()
end function

sub saveCountry(country as String)
    sec = CreateObject("roRegistrySection", "FreeCinema")
    sec.Write("country", country)
    sec.Flush()
end sub

function getFilesUrl() as String
    sec = CreateObject("roRegistrySection", "FreeCinema")
    if sec.Exists("filesUrl") then return sec.Read("filesUrl")
    return DefaultFilesUrl()
end function

sub loadPlaylist()
    url = getPlaylistUrl()
    if url = "" and getFilesUrl() = ""
        showStatus("No playlist URL set yet." + chr(10) + "Press * on your remote and choose ""Set playlist URL"".")
        return
    end if

    showStatus("Loading channels...")
    if m.task <> invalid
        m.task.unobserveField("rows")
        m.task.unobserveField("error")
        m.task.control = "stop"
    end if
    m.task = CreateObject("roSGNode", "PlaylistTask")
    m.task.observeField("rows", "onRowsLoaded")
    m.task.observeField("error", "onLoadError")
    m.task.url = url
    m.task.country = getCountry()
    m.task.filesUrl = getFilesUrl()
    m.task.control = "run"
end sub

sub onRowsLoaded()
    if m.task.rows = invalid then return
    m.channels = m.task.channels
    if m.channels = invalid then m.channels = []
    m.allContent = m.task.rows
    m.channelByUrl = {}
    for each ch in m.channels
        m.channelByUrl[ch.url] = ch
    end for
    m.rowNames = []
    for i = 0 to m.allContent.getChildCount() - 1
        m.rowNames.Push(m.allContent.getChild(i).id)
    end for
    refreshFavoriteRows()

    m.searchActive = false
    m.rowList.content = m.allContent
    m.status.visible = false
    m.rowList.visible = true
    if m.top.dialog = invalid then m.rowList.setFocus(true)
    updateHint()
end sub

' ---------- Video quality ----------

' Labels and max bandwidth (Kbps) for adaptive streams. 0 = no cap (Auto).
function qualityOptions() as Object
    return [
        { label: "Auto (best available)", short: "Auto",  kbps: 0 }
        { label: "1080p - High",          short: "1080p", kbps: 7000 }
        { label: "720p - Medium",         short: "720p",  kbps: 3500 }
        { label: "480p - Low",            short: "480p",  kbps: 1500 }
        { label: "360p - Data Saver",     short: "360p",  kbps: 900 }
    ]
end function

function getQualityIndex() as Integer
    sec = CreateObject("roRegistrySection", "FreeCinema")
    if sec.Exists("quality")
        index = sec.Read("quality").ToInt()
        if index >= 0 and index < qualityOptions().Count() then return index
    end if
    return 0
end function

sub showQualityPicker()
    current = getQualityIndex()
    labels = []
    options = qualityOptions()
    for i = 0 to options.Count() - 1
        label = options[i].label
        if i = current then label = label + "   (last used)"
        labels.Push(label)
    end for
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Video quality"
    dialog.message = ["Lower quality uses less data. Streams that offer only one quality will play as-is."]
    dialog.buttons = labels
    dialog.observeFieldScoped("buttonSelected", "onQualityButton")
    dialog.observeFieldScoped("wasClosed", "onQualityClosed")
    m.top.dialog = dialog
end sub

sub onQualityButton()
    index = m.top.dialog.buttonSelected
    sec = CreateObject("roRegistrySection", "FreeCinema")
    sec.Write("quality", StrI(index).Trim())
    sec.Flush()
    m.top.dialog.close = true
end sub

sub onQualityClosed()
    if m.rowList.visible then m.rowList.setFocus(true) else m.top.setFocus(true)
    updateHint()
end sub

function focusedChannel() as Dynamic
    if not m.rowList.visible or m.rowList.content = invalid then return invalid
    sel = m.rowList.rowItemFocused
    if sel = invalid or sel.Count() < 2 or sel[0] < 0 then return invalid
    row = m.rowList.content.getChild(sel[0])
    if row = invalid then return invalid
    return row.getChild(sel[1])
end function

sub updateHint()
    if m.searchActive
        base = "Back: all channels"
    else
        base = StrI(m.channels.Count()).Trim() + " channels  -  " + qualityOptions()[getQualityIndex()].short + "  -  * Menu"
    end if
    item = focusedChannel()
    if item <> invalid
        if isFavorite(item.url)
            base = base + "  -  Play/Pause: remove from favorites"
        else
            base = base + "  -  Play/Pause: add to favorites"
        end if
    end if
    m.hint.text = base
end sub

sub toggleFocusedFavorite()
    item = focusedChannel()
    if item = invalid then return
    title = item.title
    sel = m.rowList.rowItemFocused
    oldFavRows = favoriteRowCount()

    if not toggleFavorite(item.url)
        showMessage("Favorites full", "You can save up to " + StrI(MaxFavorites()).Trim() + " favorites. Remove one first.")
        return
    end if

    ' Keep focus on the same channel when the favorites rows above it grow or shrink.
    if not m.searchActive
        newFavRows = favoriteRowCount()
        if sel[0] >= oldFavRows
            m.rowList.jumpToRowItem = [sel[0] - oldFavRows + newFavRows, sel[1]]
        else
            m.rowList.jumpToRowItem = [0, 0]
        end if
    end if
    updateHint()
end sub

sub onLoadError()
    showStatus(m.task.error + chr(10) + chr(10) + "Press * to change the playlist URL or reload.")
end sub

sub showStatus(text as String)
    m.rowList.visible = false
    m.status.text = text
    m.status.visible = true
    if m.top.dialog = invalid then m.top.setFocus(true)
end sub

' ---------- Playback ----------

sub onItemSelected()
    sel = m.rowList.rowItemSelected
    row = m.rowList.content.getChild(sel[0])
    if row = invalid then return
    item = row.getChild(sel[1])
    if item <> invalid then playItem(item)
end sub

sub playItem(item as Object)
    content = CreateObject("roSGNode", "ContentNode")
    content.title = item.title
    content.url = item.url
    content.streamFormat = item.streamFormat
    kbps = qualityOptions()[getQualityIndex()].kbps
    if kbps > 0 then content.MaxBandwidth = kbps
    if item.HttpHeaders <> invalid and item.HttpHeaders.Count() > 0 then content.HttpHeaders = item.HttpHeaders
    m.video.content = content
    m.video.visible = true
    m.video.setFocus(true)
    m.video.control = "play"
end sub

sub onVideoState()
    if m.video.state = "error"
        title = ""
        if m.video.content <> invalid then title = m.video.content.title
        stopVideo()
        showMessage("Stream unavailable", title + " could not be played." + chr(10) + m.video.errorMsg)
    else if m.video.state = "finished"
        stopVideo()
    end if
end sub

sub stopVideo()
    m.video.control = "stop"
    m.video.visible = false
    if m.rowList.visible then m.rowList.setFocus(true) else m.top.setFocus(true)
end sub

' ---------- Search ----------

sub doSearch(query as String)
    q = LCase(query.Trim())
    if q = ""
        clearSearch()
        return
    end if

    results = CreateObject("roSGNode", "ContentNode")
    row = results.CreateChild("ContentNode")
    count = 0
    for each ch in m.channels
        if Instr(1, LCase(ch.name), q) > 0 or Instr(1, LCase(ch.group), q) > 0
            SetChannelFields(row.CreateChild("ContentNode"), ch)
            count = count + 1
        end if
    end for

    if count = 0
        showMessage("No matches", "No channels match """ + query.Trim() + """.")
        return
    end if

    row.title = "Search: " + query.Trim() + "  (" + StrI(count).Trim() + ")"
    m.searchActive = true
    m.rowList.content = results
    m.rowList.visible = true
    m.status.visible = false
    m.rowList.setFocus(true)
    updateHint()
end sub

sub clearSearch()
    m.searchActive = false
    if m.allContent <> invalid
        m.rowList.content = m.allContent
        m.rowList.setFocus(true)
    end if
    updateHint()
end sub

' ---------- Dialogs ----------

sub showMenu()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "FreeCinema"
    dialog.message = ["Choose an option"]
    if getCountry() = ""
        countryButton = "Show US channels only"
    else
        countryButton = "Show all countries"
    end if
    m.menuActions = []
    labels = []
    item = focusedChannel()
    if item <> invalid
        if isFavorite(item.url)
            labels.Push("Remove """ + item.title + """ from favorites")
        else
            labels.Push("Add """ + item.title + """ to favorites")
        end if
        m.menuActions.Push("favorite")
    end if
    labels.Append(["Search channels", "Video quality: " + qualityOptions()[getQualityIndex()].short, countryButton, "Set playlist URL", "Set My Files website", "Reload playlist", "Cancel"])
    m.menuActions.Append(["search", "quality", "country", "url", "files", "reload", "cancel"])
    dialog.buttons = labels
    dialog.observeFieldScoped("buttonSelected", "onMenuButton")
    m.top.dialog = dialog
end sub

sub onMenuButton()
    action = m.menuActions[m.top.dialog.buttonSelected]
    m.top.dialog.close = true
    if action = "favorite"
        toggleFocusedFavorite()
    else if action = "quality"
        showQualityPicker()
    else if action = "search"
        showKeyboard("Search channels", "", "search")
    else if action = "country"
        if getCountry() = "" then saveCountry("us") else saveCountry("")
        loadPlaylist()
    else if action = "url"
        showKeyboard("Playlist URL (M3U)", getPlaylistUrl(), "url")
    else if action = "files"
        showKeyboard("My Files website URL", getFilesUrl(), "files")
    else if action = "reload"
        loadPlaylist()
    end if
end sub

sub showKeyboard(title as String, text as String, purpose as String)
    m.keyboardPurpose = purpose
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = title
    dialog.text = text
    dialog.buttons = ["OK", "Cancel"]
    dialog.observeFieldScoped("buttonSelected", "onKeyboardButton")
    m.top.dialog = dialog
end sub

sub onKeyboardButton()
    dialog = m.top.dialog
    index = dialog.buttonSelected
    text = dialog.text
    dialog.close = true
    if index <> 0 then return

    if m.keyboardPurpose = "search"
        doSearch(text)
    else if m.keyboardPurpose = "url"
        savePlaylistUrl(text.Trim())
        loadPlaylist()
    else if m.keyboardPurpose = "files"
        sec = CreateObject("roRegistrySection", "FreeCinema")
        sec.Write("filesUrl", text.Trim())
        sec.Flush()
        loadPlaylist()
    end if
end sub

sub showMessage(title as String, text as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = title
    dialog.message = [text]
    dialog.buttons = ["OK"]
    dialog.observeFieldScoped("buttonSelected", "onMessageButton")
    m.top.dialog = dialog
end sub

sub onMessageButton()
    m.top.dialog.close = true
end sub

' ---------- Remote keys ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.video.visible
        if key = "back"
            stopVideo()
            return true
        end if
        return false
    end if

    if key = "options"
        showMenu()
        return true
    end if

    if key = "play" and m.rowList.visible
        toggleFocusedFavorite()
        return true
    end if

    if key = "back" and m.searchActive
        clearSearch()
        return true
    end if

    return false
end function
