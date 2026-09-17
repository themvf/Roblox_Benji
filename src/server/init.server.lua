local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(script.Services)
Knit.Start()
    :andThen(function()
        print("[Arena] Server started")
    end)
    :catch(warn)
