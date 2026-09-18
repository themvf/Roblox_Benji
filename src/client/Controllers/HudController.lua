-- Minimal HUD: round state, score, ammo. Replace with real UI later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local HudController = Knit.CreateController({ Name = "HudController" })

-- Slowly spin the kiosk showcase weapon so it catches the eye
local function spinShowcase()
    local RunService = game:GetService("RunService")
    task.spawn(function()
        local lobby = workspace:WaitForChild("Lobby", 30)
        local show = lobby and lobby:WaitForChild("Showcase", 30)
        if not show then
            return
        end
        local pivot = show:GetPivot()
        local angle = 0
        RunService.Heartbeat:Connect(function(dt)
            angle += dt * 0.6
            show:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, angle, 0))
        end)
    end)
end

function HudController:KnitStart()
    spinShowcase()
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

    local RoundService = Knit.GetService("RoundService")
    RoundService.StateChanged:Connect(function(s, data)
        local text = s
        if s == "Lobby" then
            text = "Stand on a pad to queue"
        elseif data.Mode then
            text = data.Mode .. "  " .. s
        end
        if data.Winner then
            text ..= " - " .. data.Winner .. " wins"
        end
        if data.Score then
            text ..= "  Red " .. data.Score.Red .. " - " .. data.Score.Blue .. " Blue"
        end
        state.Text = text
    end)
end

return HudController
