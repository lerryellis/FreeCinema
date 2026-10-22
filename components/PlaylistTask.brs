sub init()
    m.top.functionName = "run"
end sub

sub run()
    ' Personal files first; they appear at the top and skip the country filter.
    myRows = []
    if m.top.filesUrl <> "" then myRows = LoadMyFiles(m.top.filesUrl)

    channels = []
    url = m.top.url
    if url <> ""
        text = FetchText(url)
        if text <> invalid and text <> "" then channels = ParseM3U(text, m.top.country)
    end if

    if channels.Count() = 0 and myRows.Count() = 0
        if url <> "" and m.top.filesUrl = ""
            m.top.error = "Could not load any channels from:" + chr(10) + url
            if m.top.country <> "" then m.top.error = m.top.error + chr(10) + "Try * > Show all countries."
        else
            m.top.error = "Nothing could be loaded from the playlist or My Files URL."
        end if
        return
    end if

    rows = []
    rows.Append(myRows)
    rows.Append(Categorize(channels))
    for each row in myRows
        channels.Append(row.items)
    end for
    m.top.channels = channels
    ' rows is set last: the scene observes it as the "done" signal.
    m.top.rows = BuildContent(rows)
end sub

function FetchText(url as String) as Dynamic
    if LCase(Left(url, 5)) = "pkg:/" or LCase(Left(url, 5)) = "tmp:/"
        return ReadAsciiFile(url)
    end if

    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    xfer.AddHeader("User-Agent", "FreeCinema/1.0 (Roku)")
    if not xfer.AsyncGetToString() then return invalid

    msg = wait(30000, port)
    if type(msg) = "roUrlEvent" and msg.GetResponseCode() = 200 then return msg.GetString()
    xfer.AsyncCancel()
    return invalid
end function

function ParseM3U(text as String, country as String) as Object
    attrRe = CreateObject("roRegex", "([A-Za-z0-9_-]+)=""([^""]*)""", "")
    countryRe = CreateObject("roRegex", "\.([a-z]{2})(@|$)", "i")
    tidyRe = CreateObject("roRegex", "\s*(\(\d{3,4}[pi]\)|\[[^\]]*\])", "i")
    channels = []
    seen = {}
    cur = invalid

    for each raw in text.Split(chr(10))
        line = raw.Trim()
        if Left(line, 8) = "#EXTINF:"
            cur = { name: "", group: "", logo: "", tvgId: "", url: "", format: "", headers: [] }
            tvgName = ""
            for each match in attrRe.MatchAll(line)
                key = LCase(match[1])
                if key = "tvg-logo"
                    cur.logo = match[2]
                else if key = "group-title"
                    cur.group = match[2]
                else if key = "tvg-id"
                    cur.tvgId = match[2]
                else if key = "tvg-name"
                    tvgName = match[2]
                else if key = "http-user-agent"
                    cur.headers.Push("User-Agent:" + match[2])
                else if key = "http-referrer"
                    cur.headers.Push("Referer:" + match[2])
                end if
            end for
            ' Display name is the text after the first comma outside of attribute values.
            rest = attrRe.ReplaceAll(line, "")
            comma = Instr(1, rest, ",")
            if comma > 0 then cur.name = Mid(rest, comma + 1).Trim()
            if cur.name = "" then cur.name = tvgName
            cur.name = tidyRe.ReplaceAll(cur.name, "").Trim()
            if cur.name = "" then cur.name = "Unknown channel"
        else if Left(line, 12) = "#EXTVLCOPT:h"
            if cur <> invalid then AddVlcHeader(cur, Mid(line, 12))
        else if Left(line, 8) = "#EXTGRP:"
            if cur <> invalid and cur.group = "" then cur.group = Mid(line, 9).Trim()
        else if line <> "" and Left(line, 1) <> "#"
            if cur <> invalid and seen[line] = invalid and MatchesCountry(countryRe, cur.tvgId, country)
                seen[line] = true
                cur.url = line
                cur.format = StreamFormatFor(line)
                channels.Push(cur)
            end if
            cur = invalid
        end if
    end for
    return channels
end function

function MatchesCountry(countryRe as Object, tvgId as String, country as String) as Boolean
    if country = "" then return true
    match = countryRe.Match(tvgId)
    return match.Count() > 1 and LCase(match[1]) = LCase(country)
end function

' Handles "#EXTVLCOPT:http-user-agent=..." / "http-referrer=..." unless the same header came from #EXTINF.
sub AddVlcHeader(cur as Object, opt as String)
    eq = Instr(1, opt, "=")
    if eq = 0 then return
    key = LCase(Left(opt, eq - 1).Trim())
    value = Mid(opt, eq + 1).Trim()
    if key = "http-user-agent"
        name = "User-Agent:"
    else if key = "http-referrer"
        name = "Referer:"
    else
        return
    end if
    for each h in cur.headers
        if Left(h, Len(name)) = name then return
    end for
    cur.headers.Push(name + value)
end sub

function StreamFormatFor(url as String) as String
    u = LCase(url)
    if Instr(1, u, ".mpd") > 0 then return "dash"
    if Instr(1, u, ".mp4") > 0 then return "mp4"
    if Instr(1, u, ".mkv") > 0 then return "mkv"
    if Instr(1, u, ".mp3") > 0 then return "mp3"
    return "hls"
end function

function BuildContent(rows as Object) as Object
    root = CreateObject("roSGNode", "ContentNode")
    for each row in rows
        rowNode = root.CreateChild("ContentNode")
        rowNode.id = row.title
        rowNode.title = row.title + "  (" + StrI(row.items.Count()).Trim() + ")"
        for each ch in row.items
            SetChannelFields(rowNode.CreateChild("ContentNode"), ch)
        end for
    end for
    return root
end function
