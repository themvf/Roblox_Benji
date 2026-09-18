-- Sends swings for melee tools (tools with the WeaponClass attribute "Melee").
-- Bullet weapons are handled entirely by the Weapons Kit and never reach this.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local MeleeController = Knit.CreateController({ Name = "MeleeController" })

local function equippedMelee()
    local character = Players.LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    if tool and tool:GetAttribute("WeaponClass") == "Melee" and Weapons[tool.Name] then
        return tool
    end
    return nil
end

function MeleeController:KnitStart()
    local MeleeService = Knit.GetService("MeleeService")
    local holding = false
    local lastLocal = 0

    local function trySwing()
        local tool = equippedMelee()
        if not tool then
            return
        end
        local stats = Weapons[tool.Name]
        if os.clock() - lastLocal < stats.Cooldown then
            return
        end
        lastLocal = os.clock()
        MeleeService:Swing(tool.Name)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            holding = true
            trySwing()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            holding = false
        end
    end)
    -- Hold to keep swinging, like Rivals melee
    game:GetService("RunService").Heartbeat:Connect(function()
        if holding then
            trySwing()
        end
    end)
end

return MeleeController
