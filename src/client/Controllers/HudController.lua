-- Minimal HUD: round state, score, ammo. Replace with real UI later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local HudController = Knit.CreateController({ Name = "HudController" })

function HudController:KnitStart()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Hud"
    gui.ResetOnSpawn = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

    local function label(pos)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.fromScale(0.3, 0.06)
        l.Position = pos
        l.BackgroundTransparency = 0.4
        l.BackgroundColor3 = Color3.new(0, 0, 0)
        l.TextColor3 = Color3.new(1, 1, 1)
        l.TextScaled = true
        l.Font = Enum.Font.GothamBold
        l.Parent = gui
        return l
    end
    local state = label(UDim2.fromScale(0.35, 0.02))
    local ammo = label(UDim2.fromScale(0.68, 0.9))

    local RoundService = Knit.GetService("RoundService")
    RoundService.StateChanged:Connect(function(s, data)
        local text = s
        if data.Winner then
            text ..= " - " .. data.Winner .. " wins"
        end
        if data.Score then
            text ..= "  Red " .. data.Score.Red .. " - " .. data.Score.Blue .. " Blue"
        end
        state.Text = text
    end)

    local Weapon = Knit.GetController("WeaponController")
    RunService.RenderStepped:Connect(function()
        local a = Weapon:GetAmmo()
        local function fmt(n)
            return n == math.huge and "INF" or tostring(n)
        end
        local status = Weapon.Reloading and "Reloading..." or (fmt(a.Mag) .. " / " .. fmt(a.Reserve))
        ammo.Text = Weapon.Current .. "  " .. status
    end)
end

return HudController
