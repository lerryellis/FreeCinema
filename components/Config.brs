' Playlists offered in the source picker at launch. The first one is the default.
' country: two-letter code matched against tvg-id (e.g. "NBCNews.us") to filter; "" keeps all.
function PlaylistSources() as Object
    return [
        { name: "Ellis TV Main",        url: "https://iptv-org.github.io/iptv/index.m3u",               country: "us" }
        { name: "Global Sports",        url: "https://iptv-org.github.io/iptv/categories/sports.m3u",   country: "" }
        { name: "UK Channels",          url: "https://iptv-org.github.io/iptv/countries/gb.m3u",        country: "" }
        { name: "US Channels",          url: "https://iptv-org.github.io/iptv/countries/us.m3u",        country: "" }
    ]
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
