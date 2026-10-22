sub init()
    m.status = m.top.findNode("status")
    m.fadeOut = m.top.findNode("fadeOut")
    m.fadeOut.observeField("state", "onFadeState")
    m.loops = []
    for each id in ["spin", "spinMid", "spinInner", "pulse", "sweep"]
        anim = m.top.findNode(id)
        anim.control = "start"
        m.loops.Push(anim)
    end for
    createParticles(18)
    m.dotTimer = CreateObject("roSGNode", "Timer")
    m.dotTimer.duration = 0.5
    m.dotTimer.repeat = true
    m.dotTimer.observeField("fire", "onDots")
    m.dotTimer.control = "start"
    m.dots = 0
    m.baseMessage = "Loading channels"
end sub

' Glowing particles drifting upward around the badge, each on its own loop.
sub createParticles(count as Integer)
    colors = ["0xFCD116FF", "0xCE1126FF", "0x00A35FFF", "0xFFFFFFFF"]
    layer = m.top.findNode("particles")
    for i = 0 to count - 1
        size = 14 + Rnd(26)
        angle = Rnd(0) * 6.2832
        radius = 140 + Rnd(230)
        x = 960 + Cos(angle) * radius - size / 2
        y = 421 + Sin(angle) * radius * 0.85 - size / 2
        drift = 90 + Rnd(110)

        dot = layer.CreateChild("Poster")
        dot.uri = "pkg:/images/glow.png"
        dot.width = size
        dot.height = size
        dot.blendColor = colors[i mod colors.Count()]
        dot.opacity = 0
        dot.id = "p" + StrI(i).Trim()

        anim = layer.CreateChild("Animation")
        anim.duration = 3.0 + Rnd(0) * 3.5
        anim.repeat = true
        anim.easeFunction = "linear"
        anim.delay = Rnd(0) * 2.5
        move = anim.CreateChild("Vector2DFieldInterpolator")
        move.key = [0.0, 1.0]
        move.keyValue = [[x, y], [x + (Rnd(0) - 0.5) * 60, y - drift]]
        move.fieldToInterp = dot.id + ".translation"
        fade = anim.CreateChild("FloatFieldInterpolator")
        fade.key = [0.0, 0.3, 0.75, 1.0]
        fade.keyValue = [0.0, 0.85, 0.5, 0.0]
        fade.fieldToInterp = dot.id + ".opacity"
        anim.control = "start"
        m.loops.Push(anim)
    end for
end sub

sub onDots()
    m.dots = (m.dots + 1) mod 4
    m.status.text = m.baseMessage + String(m.dots, ".")
end sub

sub onMessage()
    m.baseMessage = m.top.message
    m.status.text = m.baseMessage
end sub

sub onDismiss()
    if m.top.dismiss then m.fadeOut.control = "start"
end sub

sub onFadeState()
    if m.fadeOut.state = "stopped"
        m.top.visible = false
        m.dotTimer.control = "stop"
        for each anim in m.loops
            anim.control = "stop"
        end for
    end if
end sub
