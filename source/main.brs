sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Deep link at launch, e.g. http://<roku>:8060/launch/dev?contentId=ESPN
    if args <> invalid and args.contentId <> invalid then scene.launchArgs = args

    ' Deep links while the app is already open (roInput / ECP /input).
    input = CreateObject("roInput")
    input.SetMessagePort(port)

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed()
            return
        else if type(msg) = "roInputEvent" and msg.IsInput()
            info = msg.GetInfo()
            if info <> invalid and info.contentId <> invalid then scene.launchArgs = info
        end if
    end while
end sub
