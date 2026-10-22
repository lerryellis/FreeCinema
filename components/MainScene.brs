sub init()
    m.video = m.top.findNode("video")
    m.panel = m.top.findNode("panel")
    m.categoryList = m.top.findNode("categoryList")
    m.channelList = m.top.findNode("channelList")
    m.status = m.top.findNode("status")
    m.hint = m.top.findNode("hint")
    m.nowPlayingGroup = m.top.findNode("nowPlayingGroup")
    m.nowPlaying = m.top.findNode("nowPlaying")
    m.loading = m.top.findNode("loading")
    m.panelAnim = m.top.findNode("panelAnim")
    m.panelSlide = m.top.findNode("panelSlide")
    m.panelFade = m.top.findNode("panelFade")
    m.barAnim = m.top.findNode("barAnim")
    m.barFade = m.top.findNode("barFade")
    m.barTimer = m.top.findNode("barTimer")
    m.barTimer.observeField("fire", "onBarTimer")
    m.panelShown = true
    m.barShown = false

    m.categoryList.observeField("itemFocused", "onCategoryFocused")
    m.channelList.observeField("itemSelected", "onChannelSelected")
    m.channelList.observeField("itemFocused", "updateHint")
    m.video.observeField("state", "onVideoState")

    m.channels = []
    m.allContent = invalid
    m.listContent = invalid
    m.searchActive = false
    m.task = invalid
    m.channelByUrl = {}
    m.rowNames = []
    m.playing = invalid
    loadFavorites()

    ' Resume the last watched channel in the background while the playlist loads.
    last = loadLastChannel()
    if last <> invalid then playItem(last)

    m.askedQuality = false
    loadPlaylist()
end sub

' The quality picker waits until the loading screen has faded, so the brand animation is visible.
sub askQualityOnce()
    if m.askedQuality then return
    m.askedQuality = true
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
    showLists(m.allContent, 0, 0)
    m.loading.dismiss = true
    m.categoryList.setFocus(true)
    askQualityOnce()
end sub

' Shows a rows tree (root > category rows > channels) in the two-column panel.
sub showLists(content as Object, categoryIndex as Integer, channelIndex as Integer)
    m.listContent = content
    m.categoryList.content = content
    if categoryIndex >= content.getChildCount() then categoryIndex = 0
    m.categoryList.jumpToItem = categoryIndex
    m.channelList.content = content.getChild(categoryIndex)
    if m.channelList.content <> invalid and channelIndex < m.channelList.content.getChildCount()
        m.channelList.jumpToItem = channelIndex
    end if
    m.status.visible = false
    m.categoryList.visible = true
    m.channelList.visible = true
    updateHint()
end sub

sub onCategoryFocused()
    if m.listContent = invalid then return
    row = m.listContent.getChild(m.categoryList.itemFocused)
    if row <> invalid and not row.isSameNode(m.channelList.content)
        m.channelList.content = row
        m.channelList.jumpToItem = 0
    end if
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
    ' Re-open the current stream so the new bandwidth cap applies.
    if m.playing <> invalid then playItem(m.playing)
    restoreFocus()
    updateHint()
end sub

sub restoreFocus()
    if not m.panelShown
        m.top.setFocus(true)
    else if m.channelList.content <> invalid and m.channelList.content.getChildCount() > 0 and m.focusOnChannels = true
        m.channelList.setFocus(true)
    else if m.listContent <> invalid
        m.categoryList.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

function focusedChannel() as Dynamic
    if not m.panelShown or not m.channelList.hasFocus() then return invalid
    row = m.channelList.content
    if row = invalid then return invalid
    return row.getChild(m.channelList.itemFocused)
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
            base = base + chr(10) + "Play/Pause: remove favorite"
        else
            base = base + chr(10) + "Play/Pause: add favorite"
        end if
    else if m.playing <> invalid
        base = base + chr(10) + "Back: full screen"
    end if
    m.hint.text = base
end sub

sub toggleFocusedFavorite()
    item = focusedChannel()
    if item = invalid then return
    categoryId = m.channelList.content.id
    channelIndex = m.channelList.itemFocused

    if not toggleFavorite(item.url)
        showMessage("Favorites full", "You can save up to " + StrI(MaxFavorites()).Trim() + " favorites. Remove one first.")
        return
    end if

    ' Favorites rows were rebuilt above the other categories: re-select the same category.
    if not m.searchActive
        categoryIndex = 0
        for i = 0 to m.allContent.getChildCount() - 1
            if m.allContent.getChild(i).id = categoryId
                categoryIndex = i
                exit for
            end if
        end for
        if m.allContent.getChild(categoryIndex).id <> categoryId then channelIndex = 0
        showLists(m.allContent, categoryIndex, channelIndex)
        if m.channelList.content <> invalid and m.channelList.content.getChildCount() > 0
            m.channelList.setFocus(true)
        else
            m.categoryList.setFocus(true)
        end if
    end if
    updateHint()
end sub

sub onLoadError()
    m.loading.dismiss = true
    askQualityOnce()
    showStatus(m.task.error + chr(10) + chr(10) + "Press * to change the playlist URL or reload.")
end sub

sub showStatus(text as String)
    m.categoryList.visible = false
    m.channelList.visible = false
    m.status.text = text
    m.status.visible = true
    showPanel()
end sub

' ---------- Panel ----------

sub showPanel()
    if not m.panelShown
        m.panelShown = true
        animatePanel(true)
    end if
    m.barTimer.control = "stop"
    setBarVisible(m.playing <> invalid)
    if m.top.dialog = invalid then restoreFocus()
    updateHint()
end sub

sub hidePanel()
    if m.playing = invalid then return
    m.panelShown = false
    animatePanel(false)
    m.top.setFocus(true)
    flashBar()
end sub

sub animatePanel(show as Boolean)
    if show
        m.panelSlide.keyValue = [[-660, 0], [0, 0]]
        m.panelFade.keyValue = [0.0, 1.0]
    else
        m.panelSlide.keyValue = [[0, 0], [-660, 0]]
        m.panelFade.keyValue = [1.0, 0.0]
    end if
    m.panelAnim.control = "start"
end sub

sub setBarVisible(show as Boolean)
    if show = m.barShown then return
    m.barShown = show
    if show then m.barFade.keyValue = [m.nowPlayingGroup.opacity, 1.0] else m.barFade.keyValue = [m.nowPlayingGroup.opacity, 0.0]
    m.barAnim.control = "start"
end sub

' In full screen the now-playing bar shows briefly, then fades away.
sub flashBar()
    setBarVisible(true)
    if not m.panelShown
        m.barTimer.control = "stop"
        m.barTimer.control = "start"
    end if
end sub

sub onBarTimer()
    if not m.panelShown then setBarVisible(false)
end sub

' ---------- Playback ----------

sub onChannelSelected()
    item = m.channelList.content.getChild(m.channelList.itemSelected)
    if item = invalid then return
    ' Selecting the channel that is already on goes full screen.
    if m.playing <> invalid and m.playing.url = item.url and m.video.state = "playing"
        hidePanel()
    else
        playItem(item)
    end if
end sub

sub playItem(item as Object)
    content = CreateObject("roSGNode", "ContentNode")
    content.title = item.title
    content.url = item.url
    content.streamFormat = item.streamFormat
    content.HDPosterUrl = item.HDPosterUrl
    kbps = qualityOptions()[getQualityIndex()].kbps
    if kbps > 0 then content.MaxBandwidth = kbps
    if item.HttpHeaders <> invalid and item.HttpHeaders.Count() > 0 then content.HttpHeaders = item.HttpHeaders
    m.playing = content
    m.video.content = content
    m.video.control = "play"
    m.nowPlaying.text = "Loading  " + item.title + " ..."
    if m.panelShown then setBarVisible(true) else flashBar()
    saveLastChannel(content)
    updateHint()
end sub

' Moves up/down within the current channel list while in full screen.
sub zapChannel(delta as Integer)
    row = m.channelList.content
    if row = invalid or row.getChildCount() = 0 then return
    index = m.channelList.itemFocused + delta
    if index < 0 then index = row.getChildCount() - 1
    if index >= row.getChildCount() then index = 0
    m.channelList.jumpToItem = index
    playItem(row.getChild(index))
end sub

sub onVideoState()
    state = m.video.state
    if m.playing = invalid then return
    if state = "playing"
        m.nowPlaying.text = "Now playing:  " + m.playing.title
    else if state = "buffering"
        m.nowPlaying.text = "Loading  " + m.playing.title + " ..."
    else if state = "error"
        m.nowPlaying.text = m.playing.title + " is unavailable right now. Pick another channel."
        showPanel()
    end if
end sub

sub saveLastChannel(content as Object)
    data = {
        title: content.title
        url: content.url
        streamFormat: content.streamFormat
        logo: content.HDPosterUrl
        headers: content.HttpHeaders
    }
    sec = CreateObject("roRegistrySection", "FreeCinema")
    sec.Write("lastChannel", FormatJson(data))
    sec.Flush()
end sub

function loadLastChannel() as Dynamic
    sec = CreateObject("roRegistrySection", "FreeCinema")
    if not sec.Exists("lastChannel") then return invalid
    data = ParseJson(sec.Read("lastChannel"))
    if type(data) <> "roAssociativeArray" or data.url = invalid or data.url = "" then return invalid
    item = CreateObject("roSGNode", "ContentNode")
    item.title = data.title
    item.url = data.url
    item.streamFormat = data.streamFormat
    if data.logo <> invalid then item.HDPosterUrl = data.logo
    if type(data.headers) = "roArray" then item.HttpHeaders = data.headers
    return item
end function

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
    showLists(results, 0, 0)
    m.focusOnChannels = true
    m.channelList.setFocus(true)
    updateHint()
end sub

sub clearSearch()
    m.searchActive = false
    if m.allContent <> invalid
        showLists(m.allContent, 0, 0)
        m.focusOnChannels = false
        m.categoryList.setFocus(true)
    end if
    updateHint()
end sub

' ---------- Dialogs ----------

sub showMenu()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Ellis TV"
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

    ' Full screen: Up/Down zaps, any other key brings the panel back.
    if not m.panelShown
        if key = "up"
            zapChannel(-1)
        else if key = "down"
            zapChannel(1)
        else if key = "options"
            showPanel()
            showMenu()
        else
            showPanel()
        end if
        return true
    end if

    if key = "options"
        showMenu()
        return true
    end if

    if key = "right" and m.categoryList.hasFocus()
        if m.channelList.content <> invalid and m.channelList.content.getChildCount() > 0
            m.focusOnChannels = true
            m.channelList.setFocus(true)
            updateHint()
        end if
        return true
    end if

    if key = "left" and m.channelList.hasFocus()
        m.focusOnChannels = false
        m.categoryList.setFocus(true)
        updateHint()
        return true
    end if

    if key = "play" and m.channelList.hasFocus()
        toggleFocusedFavorite()
        return true
    end if

    if key = "back"
        if m.searchActive
            clearSearch()
            return true
        end if
        if m.playing <> invalid
            hidePanel()
            return true
        end if
    end if

    return false
end function
