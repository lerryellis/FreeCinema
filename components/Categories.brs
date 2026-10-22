' Genre rows, shown in this order. A channel can appear in several rows.
' Patterns are matched (case-insensitive) against: name + group-title + tvg-id.
function GetGenreRules() as Object
    return [
        { name: "Comedy",      pattern: "\b(comedy|comedies|comedia|comedie|laugh|laughs|funny|stand-?up|jokes|humor|humour)\b" }
        { name: "Sports",      pattern: "\b(sports?|deportes?|espn|nfl|nba|wnba|mlb|nhl|mls|ncaa|golf|tennis|racing|nascar|f1|motorsports?|boxing|ufc|mma|wrestling|wwe|soccer|football|futbol|baseball|basketball|hockey|cricket|rugby|bein|dazn|fubo|olympics?|fishing|hunting|poker)\b" }
        { name: "Documentary", pattern: "\b(documentar\w*|docu\w*|history|historia|nature|science|discovery|nat ?geo|national geographic|smithsonian|curiosity|wildlife|animal planet|biography|true crime|travel)\b" }
        { name: "Movies",      pattern: "\b(movies?|films?|cinema|cine|peliculas?|filmes?|flix|hollywood|blockbusters?)\b" }
        { name: "Sitcoms",     pattern: "\b(sitcoms?|seinfeld|the office|frasier|happy days|three'?s company|king of queens|everybody loves raymond|family matters|fresh prince|married with children|bewitched|i love lucy|andy griffith|brady bunch|m\*?a\*?s\*?h|sanford|jeffersons|golden girls|full house|home improvement|3rd rock|malcolm in the middle|that '?70s show|parks and rec\w*|30 rock|the nanny|roseanne|carol burnett)\b" }
        { name: "Old School",  pattern: "\b(classics?|retro|vintage|oldies|old ?school|throwback|nostalgi\w*|golden age|decades|me ?tv|antenna tv|rewind|westerns?|black (and|&) white|[5-9]0'?s)\b" }
        { name: "News",        pattern: "\b(news|noticias|weather|bloomberg|c-?span|cnn|msnbc|cnbc|newsmax)\b" }
        { name: "Kids",        pattern: "\b(kids?|children|cartoons?|toons?|anime|animation|nick|nickelodeon|disney|junior|baby)\b" }
        { name: "Music",       pattern: "\b(music|musica|mtv|vevo|hits|concerts?|karaoke)\b" }
    ]
end function

' Network rows, shown after the genre rows.
function GetNetworkRules() as Object
    return [
        { name: "NBC",  pattern: "\b([kw][a-z]{0,3})?nbc|\b(peacock|telemundo)" }
        { name: "FOX",  pattern: "\b([kw][a-z]{0,3})?fox" }
        { name: "ESPN", pattern: "\bespn" }
        { name: "CBS",  pattern: "\bcbs" }
        { name: "ABC",  pattern: "\babc\b" }
        { name: "PBS",  pattern: "\bpbs\b" }
    ]
end function

' Returns an ordered array of { title, items[] } rows.
function Categorize(channels as Object) as Object
    rules = []
    for each r in GetGenreRules()
        rules.Push({ name: r.name, re: CreateObject("roRegex", r.pattern, "i") })
    end for
    for each r in GetNetworkRules()
        rules.Push({ name: r.name, re: CreateObject("roRegex", r.pattern, "i") })
    end for

    buckets = {}
    extraNames = []
    for each ch in channels
        text = ch.name + " " + ch.group + " " + ch.tvgId
        matched = false
        for each rule in rules
            if rule.re.IsMatch(text)
                AddToBucket(buckets, rule.name, ch)
                matched = true
            end if
        end for
        if not matched
            name = FallbackGroup(ch.group)
            if buckets[name] = invalid and name <> "Other" then extraNames.Push(name)
            AddToBucket(buckets, name, ch)
        end if
    end for

    order = []
    for each rule in rules
        order.Push(rule.name)
    end for
    extraNames.Sort("i")
    order.Append(extraNames)
    order.Push("Other")

    rows = []
    for each name in order
        items = buckets[name]
        if items <> invalid and items.Count() > 0
            items.SortBy("name", "i")
            rows.Push({ title: name, items: items })
        end if
    end for
    return rows
end function

sub AddToBucket(buckets as Object, name as String, ch as Object)
    if buckets[name] = invalid then buckets[name] = []
    buckets[name].Push(ch)
    ' Remember every row a channel lands in, so favorites can be grouped the same way.
    if ch.cats = invalid then ch.cats = []
    ch.cats.Push(name)
end sub

' Uses the playlist's own group-title (first segment) for channels no rule matched.
function FallbackGroup(group as String) as String
    g = group.Split(";")[0]
    if g = invalid then return "Other"
    g = g.Trim()
    if g = "" or LCase(g) = "undefined" or LCase(g) = "general" or LCase(g) = "other" then return "Other"
    return g
end function
