' Favorites are stored in the registry as a JSON array of stream URLs (registry space is ~16KB,
' so only URLs are saved) and resolved against the loaded playlist. They are shown at the top
' of the main content as "Favorites - All" plus one row per genre/network the channel belongs to.

function MaxFavorites() as Integer
    return 100
end function

sub loadFavorites()
    m.favorites = []
    m.favSet = {}
    sec = CreateObject("roRegistrySection", "FreeCinema")
    if not sec.Exists("favorites") then return
    saved = ParseJson(sec.Read("favorites"))
    if type(saved) <> "roArray" then return
    for each url in saved
        if type(url) = "roString" or type(url) = "String"
            m.favorites.Push(url)
            m.favSet[url] = true
        end if
    end for
end sub

sub saveFavorites()
    sec = CreateObject("roRegistrySection", "FreeCinema")
    sec.Write("favorites", FormatJson(m.favorites))
    sec.Flush()
end sub

' Adds each DefaultFavorites() name the first time it appears in any loaded source.
' Restored names are remembered in "favSeeded" (same registry), so a wipe brings the backup back
' while favorites you remove later stay removed.
sub seedDefaultFavorites()
    sec = CreateObject("roRegistrySection", "FreeCinema")
    done = {}
    if sec.Exists("favSeeded")
        saved = ParseJson(sec.Read("favSeeded"))
        if type(saved) = "roArray"
            for each name in saved
                done[name] = true
            end for
        end if
    end if
    wanted = {}
    for each name in DefaultFavorites()
        if not done.DoesExist(LCase(name)) then wanted[LCase(name)] = true
    end for
    if wanted.Count() = 0 then return

    added = 0
    for each ch in m.channels
        key = LCase(ch.name)
        if wanted.DoesExist(key) and m.favorites.Count() < MaxFavorites()
            if not isFavorite(ch.url)
                m.favorites.Push(ch.url)
                m.favSet[ch.url] = true
            end if
            wanted.Delete(key)
            done[key] = true
            added = added + 1
        end if
    end for
    if added = 0 then return
    saveFavorites()
    sec.Write("favSeeded", FormatJson(done.Keys()))
    sec.Flush()
end sub

function isFavorite(url as String) as Boolean
    return m.favSet.DoesExist(url)
end function

' Adds or removes the channel; returns false if the favorites list is full.
function toggleFavorite(url as String) as Boolean
    if isFavorite(url)
        m.favSet.Delete(url)
        kept = []
        for each u in m.favorites
            if u <> url then kept.Push(u)
        end for
        m.favorites = kept
    else
        if m.favorites.Count() >= MaxFavorites() then return false
        m.favorites.Push(url)
        m.favSet[url] = true
    end if
    saveFavorites()
    refreshFavoriteRows()
    return true
end function

function favoriteRowCount() as Integer
    count = 0
    if m.allContent = invalid then return 0
    for i = 0 to m.allContent.getChildCount() - 1
        if Left(m.allContent.getChild(i).id, 4) <> "fav:" then exit for
        count = count + 1
    end for
    return count
end function

' Rebuilds the favorites rows at the top of m.allContent.
' Callers must re-show the lists afterwards (showLists), because they are detached here.
sub refreshFavoriteRows()
    if m.allContent = invalid then return
    ' Detach the on-screen lists before editing their content: changing a MarkupList's
    ' content tree while it is displayed (and animating focus) can hang the UI.
    if not m.searchActive
        m.channelList.content = invalid
        m.categoryList.content = invalid
    end if
    for i = 1 to favoriteRowCount()
        m.allContent.removeChildIndex(0)
    end for

    favs = []
    for each url in m.favorites
        ch = m.channelByUrl[url]
        if ch <> invalid then favs.Push(ch)
    end for
    if favs.Count() = 0 then return
    favs.SortBy("name", "i")

    rows = [makeFavoriteRow("All", favs)]
    for each name in m.rowNames
        matches = []
        for each ch in favs
            if channelInRow(ch, name) then matches.Push(ch)
        end for
        if matches.Count() > 0 then rows.Push(makeFavoriteRow(name, matches))
    end for

    for i = 0 to rows.Count() - 1
        m.allContent.insertChild(rows[i], i)
    end for
end sub

function makeFavoriteRow(name as String, channels as Object) as Object
    row = CreateObject("roSGNode", "ContentNode")
    row.id = "fav:" + name
    if name = "All" then label = "Favorites" else label = "Fav " + name
    row.title = label + "  (" + StrI(channels.Count()).Trim() + ")"
    for each ch in channels
        SetChannelFields(row.CreateChild("ContentNode"), ch)
    end for
    return row
end function

function channelInRow(ch as Object, name as String) as Boolean
    if ch.cats = invalid then return false
    for each c in ch.cats
        if c = name then return true
    end for
    return false
end function
