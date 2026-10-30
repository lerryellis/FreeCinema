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

    return GroupFileRows(files, "My Files")
end function

' Browse a NAS over WebDAV. Roku's player cannot mount SMB shares directly, but
' WebDAV exposes the same NAS files over HTTP so the Video node can stream them.
' A NAS login can be given in the URL (http://user:pass@nas:5005/video); it is moved into a
' Basic Authorization header that is sent both for folder listings and by the video player.
function LoadWebDavFiles(url as String) as Object
    target = SplitCredentials(url.Trim())
    headers = []
    if target.auth <> "" then headers.Push("Authorization:Basic " + target.auth)
    files = CrawlWebDav(target.url, "", 0, {}, headers)
    return GroupFileRows(files, "NAS")
end function

' Returns { url (without user:pass@), auth (base64 "user:pass" or "") }.
function SplitCredentials(url as String) as Object
    result = { url: url, auth: "" }
    schemeEnd = Instr(1, url, "://")
    if schemeEnd = 0 then return result
    hostStart = schemeEnd + 3
    pathStart = Instr(hostStart, url, "/")
    if pathStart = 0 then pathStart = Len(url) + 1
    authority = Mid(url, hostStart, pathStart - hostStart)
    ' The last "@" separates the login from the host, so passwords may contain "@".
    at = 0
    for i = Len(authority) to 1 step -1
        if Mid(authority, i, 1) = "@"
            at = i
            exit for
        end if
    end for
    if at = 0 then return result
    unescaper = CreateObject("roUrlTransfer")
    login = Left(authority, at - 1)
    colon = Instr(1, login, ":")
    if colon > 0
        login = unescaper.Unescape(Left(login, colon - 1)) + ":" + unescaper.Unescape(Mid(login, colon + 1))
    else
        login = unescaper.Unescape(login) + ":"
    end if
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(login)
    result.auth = bytes.ToBase64String()
    result.url = Left(url, hostStart - 1) + Mid(authority, at + 1) + Mid(url, pathStart)
    return result
end function

function GroupFileRows(files as Object, prefix as String) as Object
    groups = {}
    order = []
    for each f in files
        g = f.group
        if g = invalid or g = "" then g = "All"
        if groups[g] = invalid
            groups[g] = []
            order.Push(g)
        end if
        f.cats = [prefix + " - " + g]
        groups[g].Push(f)
    end for

    rows = []
    for each g in order
        groups[g].SortBy("name", "i")
        rows.Push({ title: prefix + " - " + g, items: groups[g] })
    end for
    return rows
end function

' Lists each WebDAV directory and follows subfolders up to two levels. The
' original HTTP URLs remain attached to each item so Roku can seek and stream.
function CrawlWebDav(url as String, group as String, depth as Integer, visited as Object, headers as Object) as Object
    directory = url.Trim()
    if directory = "" then return []
    if Right(directory, 1) <> "/" then directory = directory + "/"
    if visited[directory] = true then return []
    visited[directory] = true

    xmlText = FetchWebDavListing(directory, headers)
    if xmlText = invalid then return []
    root = CreateObject("roXMLElement")
    if not root.Parse(xmlText) then return []

    files = []
    responses = FindDavElements(root, "response")
    for each response in responses
        href = FindDavText(response, "href")
        if href = invalid or href = "" then continue for
        full = DavHrefToUrl(directory, href)
        if full = invalid or SameDavPath(directory, full) then continue for

        isCollection = HasDavElement(response, "collection")
        if isCollection
            if depth < 2 and Left(full, Len(directory)) = directory
                folder = NameFromUrl(Left(full, Len(full) - 1))
                childGroup = folder
                if group <> "" then childGroup = group + " / " + folder
                files.Append(CrawlWebDav(full, childGroup, depth + 1, visited, headers))
            end if
        else if IsVideoPath(full)
            files.Push({ name: NameFromUrl(full), group: group, logo: "", tvgId: "", url: full, format: StreamFormatFor(full), headers: headers })
        end if
    end for
    return files
end function

function FetchWebDavListing(url as String, headers as Object) as Dynamic
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.SetRequest("PROPFIND")
    xfer.AddHeader("Depth", "1")
    xfer.AddHeader("Content-Type", "application/xml; charset=utf-8")
    xfer.AddHeader("User-Agent", "EllisTV/1.0 (Roku)")
    for each h in headers
        colon = Instr(1, h, ":")
        if colon > 1 then xfer.AddHeader(Left(h, colon - 1), Mid(h, colon + 1))
    end for
    body = "<?xml version=""1.0"" encoding=""utf-8""?><d:propfind xmlns:d=""DAV:""><d:prop><d:resourcetype/><d:getcontentlength/></d:prop></d:propfind>"
    if not xfer.AsyncPostFromString(body) then return invalid
    msg = wait(12000, port)
    if type(msg) = "roUrlEvent" and (msg.GetResponseCode() = 207 or msg.GetResponseCode() = 200)
        return msg.GetString()
    end if
    xfer.AsyncCancel()
    return invalid
end function

function FindDavElements(element as Object, tagName as String) as Object
    found = []
    children = element.GetChildElements()
    if children = invalid then return found
    for each child in children
        if DavLocalName(child.GetName()) = LCase(tagName) then found.Push(child)
        found.Append(FindDavElements(child, tagName))
    end for
    return found
end function

function FindDavText(element as Object, tagName as String) as Dynamic
    if DavLocalName(element.GetName()) = LCase(tagName) then return element.GetText()
    children = element.GetChildElements()
    if children = invalid then return invalid
    for each child in children
        value = FindDavText(child, tagName)
        if value <> invalid then return value
    end for
    return invalid
end function

function HasDavElement(element as Object, tagName as String) as Boolean
    if DavLocalName(element.GetName()) = LCase(tagName) then return true
    children = element.GetChildElements()
    if children = invalid then return false
    for each child in children
        if HasDavElement(child, tagName) then return true
    end for
    return false
end function

function DavLocalName(name as String) as String
    parts = name.Split(":")
    return LCase(parts[parts.Count() - 1])
end function

function DavHrefToUrl(baseUrl as String, href as String) as Dynamic
    value = href.Trim()
    if Left(LCase(value), 7) = "http://" or Left(LCase(value), 8) = "https://" then return value
    schemeEnd = Instr(1, baseUrl, "://")
    hostEnd = Instr(schemeEnd + 3, baseUrl, "/")
    if hostEnd = 0 then return invalid
    origin = Left(baseUrl, hostEnd - 1)
    if Left(value, 1) = "/" then return origin + value
    return ResolveUrl(baseUrl, value)
end function

function SameDavPath(a as String, b as String) as Boolean
    ' Names like "left"/"right" would shadow Left()/Right() (BrightScript is case-insensitive).
    pathA = LCase(a)
    pathB = LCase(b)
    while Right(pathA, 1) = "/" and Len(pathA) > 1
        pathA = Left(pathA, Len(pathA) - 1)
    end while
    while Right(pathB, 1) = "/" and Len(pathB) > 1
        pathB = Left(pathB, Len(pathB) - 1)
    end while
    return pathA = pathB
end function

function IsVideoPath(url as String) as Boolean
    path = LCase(url.Split("?")[0])
    dot = path.Split(".")
    if dot.Count() < 2 then return false
    ext = dot[dot.Count() - 1]
    for each supported in VideoExtensions()
        if ext = supported then return true
    end for
    return false
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
