' Default M3U playlist loaded on first launch.
' Can be overridden on the device: press * > "Set playlist URL".
function DefaultPlaylistUrl() as String
    return "https://iptv-org.github.io/iptv/index.m3u"
end function

' Two-letter country code (from tvg-id, e.g. "NBCNews.us") to keep; "" shows every country.
function DefaultCountry() as String
    return "us"
end function

' Personal website with your own videos (M3U, JSON list, or folder listing). "" = none.
function DefaultFilesUrl() as String
    return ""
end function

function DefaultLogoUri() as String
    return "pkg:/images/default_logo.png"
end function

' Copies a parsed channel (associative array) onto a ContentNode for the RowList / Video.
sub SetChannelFields(node as Object, ch as Object)
    node.title = ch.name
    logo = ch.logo
    if logo = invalid or logo = "" then logo = DefaultLogoUri()
    node.HDPosterUrl = logo
    node.FHDPosterUrl = logo
    node.url = ch.url
    node.streamFormat = ch.format
    node.description = ch.group
    if ch.headers <> invalid and ch.headers.Count() > 0 then node.HttpHeaders = ch.headers
end sub
