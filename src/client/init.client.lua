local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddControllers(script.Controllers)
Knit.Start()
    :andThen(function()
        print("[Arena] Client started")
    end)
    :catch(warn)
