local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Screen measures the viewport, device class and safe area before any HUD is built, so every
-- controller's KnitStart can position itself against real numbers on the very first frame.
require(script.UI.Screen).start()

Knit.AddControllers(script.Controllers)
Knit.Start()
    :andThen(function()
        print("[Arena] Client started")
    end)
    :catch(warn)
