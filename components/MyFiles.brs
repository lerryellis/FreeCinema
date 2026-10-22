' Loads videos from a personal website. Supports three kinds of URL:
'   - an M3U playlist (starts with #EXTM3U)
'   - a JSON list: [{ "title": "...", "url": "...", "poster": "...", "group": "..." }]
'   - a plain web-server folder listing (links to video files; subfolders become rows)

function VideoExtensions() as Object
    return ["mp4", "m4v", "mkv", "mov", "m3u8", "ts", "mpd", "mp3", "m4a"]
end function

' Returns an ordered array of { title, items[] } rows, all titled "My Files...".
function LoadMyFiles(url as String) as Object
    files = []
    text = FetchText(url)
    if text = invalid or text = "" then return []

    head = Left(text.Trim(), 1)
    if Left(text.Trim(), 7) = "#EXTM3U"
        files = ParseM3U(text, "")
    else if head = "[" or head = "{"
        files = ParseFileJson(text, url)
    else
        files = CrawlListing(url, text, "", 0, {})
    end if

    groups = {}
    order = []
    for each f in files
        g = f.group
        if g = invalid or g = "" then g = "All"
        if groups[g] = invalid
            groups[g] = []
            order.Push(g)
        end if
        f.cats = ["My Files - " + g]
        groups[g].Push(f)
    end for

    rows = []
    for each g in order
        groups[g].SortBy("name", "i")
        rows.Push({ title: "My Files - " + g, items: groups[g] })
    end for
    return rows
end function

function ParseFileJson(text as String, baseUrl as String) as Object
    data = ParseJson(text)
    if type(data) = "roAssociativeArray"
        if data.videos <> invalid then data = data.videos else data = data.items
    end if
    files = []
    if type(data) <> "roArray" then return files
    for each v in data
        if type(v) = "roAssociativeArray" and v.url <> invalid
            u = ResolveUrl(baseUrl, v.url)
            name = v.title
            if name = invalid then name = NameFromUrl(u)
            poster = v.poster
            if poster = invalid then poster = ""
            if poster <> "" then poster = ResolveUrl(baseUrl, poster)
            group = v.group
            if group = invalid then group = ""
            files.Push({ name: name, group: group, logo: poster, tvgId: "", url: u, format: StreamFormatFor(u), headers: [] })
        end if
    end for
    return files
end function

' Follows links in an HTML folder listing; subfolders (up to 2 levels) become groups.
function CrawlListing(pageUrl as String, html as String, group as String, depth as Integer, visited as Object) as Object
    visited[pageUrl] = true
    files = []
    hrefRe = CreateObject("roRegex", "href\s*=\s*[""']([^""'#]+)[""']", "i")
    exts = VideoExtensions()
    for each match in hrefRe.MatchAll(html)
        href = match[1]
        skip = Left(href, 1) = "?" or Left(href, 3) = "../" or href = "./" or href = "/" or Left(LCase(href), 7) = "mailto:"
        if not skip then files.Append(CrawlLink(pageUrl, href, group, depth, visited, exts))
    end for
    return files
end function

function CrawlLink(pageUrl as String, href as String, group as String, depth as Integer, visited as Object, exts as Object) as Object
    files = []
    full = ResolveUrl(pageUrl, href)
    path = LCase(full.Split("?")[0])
    if Right(path, 1) = "/"
        if depth < 2 and visited[full] = invalid and Left(full, Len(pageUrl)) = pageUrl and Len(full) > Len(pageUrl)
            pageHtml = FetchText(full)
            if pageHtml <> invalid
                folder = NameFromUrl(Left(full, Len(full) - 1))
                if group <> "" then folder = group + " / " + folder
                files.Append(CrawlListing(full, pageHtml, folder, depth + 1, visited))
            end if
        end if
    else
        dot = path.Split(".")
        ext = dot[dot.Count() - 1]
        for each e in exts
            if ext = e
                files.Push({ name: NameFromUrl(full), group: group, logo: "", tvgId: "", url: full, format: StreamFormatFor(full), headers: [] })
                exit for
            end if
        end for
    end if
    return files
end function

function ResolveUrl(base as String, href as String) as String
    h = href.Trim()
    if Left(LCase(h), 7) = "http://" or Left(LCase(h), 8) = "https://" then return h
    schemeEnd = Instr(1, base, "://")
    hostEnd = Instr(schemeEnd + 3, base, "/")
    if hostEnd = 0
        origin = base
        dir = base + "/"
    else
        origin = Left(base, hostEnd - 1)
        q = Instr(1, base, "?")
        clean = base
        if q > 0 then clean = Left(base, q - 1)
        parts = clean.Split("/")
        parts.Pop()
        dir = parts.Join("/") + "/"
    end if
    if Left(h, 2) = "//" then return Left(base, schemeEnd - 1) + ":" + h
    if Left(h, 1) = "/" then return origin + h
    if Left(h, 2) = "./" then h = Mid(h, 3)
    return dir + h
end function

function NameFromUrl(url as String) as String
    parts = url.Split("?")[0].Split("/")
    name = parts[parts.Count() - 1]
    name = CreateObject("roUrlTransfer").Unescape(name)
    dot = CreateObject("roRegex", "\.[A-Za-z0-9]{2,4}$", "")
    name = dot.Replace(name, "")
    name = CreateObject("roRegex", "[._]+", "").ReplaceAll(name, " ").Trim()
    if name = "" then name = "Untitled"
    return name
end function
