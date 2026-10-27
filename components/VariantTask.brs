sub init()
    m.top.functionName = "run"
end sub

sub run()
    result = { token: m.top.token, url: m.top.url, locked: false }
    text = fetchPlaylist(m.top.url, m.top.headers)
    if text <> invalid
        chosen = pickVariant(text, m.top.url, m.top.maxKbps, m.top.maxHeight)
        if chosen <> invalid
            result.url = chosen
            result.locked = true
        end if
    end if
    m.top.result = result
end sub

function fetchPlaylist(url as String, headers as Dynamic) as Dynamic
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    if type(headers) = "roArray"
        for each h in headers
            colon = Instr(1, h, ":")
            if colon > 1 then xfer.AddHeader(Left(h, colon - 1), Mid(h, colon + 1))
        end for
    end if
    if not xfer.AsyncGetToString() then return invalid
    msg = wait(8000, port)
    if type(msg) = "roUrlEvent" and msg.GetResponseCode() = 200
        text = msg.GetString()
        ' Only follow real master playlists, never huge files.
        if Len(text) < 200000 then return text
        return invalid
    end if
    xfer.AsyncCancel()
    return invalid
end function

' Returns the URL of the best rendition within the limits, or invalid to keep the master playlist
' (not a master, separate audio tracks that a single rendition would lose, or nothing parseable).
function pickVariant(text as String, baseUrl as String, maxKbps as Integer, maxHeight as Integer) as Dynamic
    if Instr(1, text, "#EXT-X-STREAM-INF") = 0 then return invalid
    audioRe = CreateObject("roRegex", "#EXT-X-MEDIA:[^\n]*TYPE=AUDIO[^\n]*URI=", "i")
    if audioRe.IsMatch(text) then return invalid

    bwRe = CreateObject("roRegex", "[:,]BANDWIDTH=(\d+)", "i")
    resRe = CreateObject("roRegex", "RESOLUTION=\d+x(\d+)", "i")
    variants = []
    pending = invalid
    for each raw in text.Split(chr(10))
        line = raw.Trim()
        if Left(line, 18) = "#EXT-X-STREAM-INF:"
            pending = { bw: 0, height: 0 }
            bw = bwRe.Match(line)
            if bw.Count() > 1 then pending.bw = bw[1].ToInt()
            res = resRe.Match(line)
            if res.Count() > 1 then pending.height = res[1].ToInt()
        else if pending <> invalid and line <> "" and Left(line, 1) <> "#"
            pending.url = resolveUrl(baseUrl, line)
            variants.Push(pending)
            pending = invalid
        end if
    end for
    if variants.Count() = 0 then return invalid

    ' Best rendition that fits both the height and the bandwidth limit; otherwise the smallest one.
    best = invalid
    smallest = variants[0]
    for each v in variants
        if v.bw < smallest.bw then smallest = v
        fitsHeight = (v.height = 0 or v.height <= maxHeight)
        fitsBw = (v.bw = 0 or v.bw <= maxKbps * 1000)
        if fitsHeight and fitsBw
            if best = invalid or v.bw > best.bw then best = v
        end if
    end for
    if best = invalid then best = smallest
    return best.url
end function

function resolveUrl(base as String, ref as String) as String
    if Instr(1, ref, "://") > 0 then return ref
    schemeEnd = Instr(1, base, "://")
    if Left(ref, 2) = "//" then return Left(base, schemeEnd) + ref
    query = Instr(1, base, "?")
    if query > 0 then base = Left(base, query - 1)
    if Left(ref, 1) = "/"
        hostEnd = Instr(schemeEnd + 3, base, "/")
        if hostEnd = 0 then return base + ref
        return Left(base, hostEnd - 1) + ref
    end if
    lastSlash = 0
    for i = Len(base) to schemeEnd + 3 step -1
        if Mid(base, i, 1) = "/"
            lastSlash = i
            exit for
        end if
    end for
    if lastSlash = 0 then return base + "/" + ref
    return Left(base, lastSlash) + ref
end function
