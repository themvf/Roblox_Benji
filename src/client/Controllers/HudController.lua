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
    local RunService = game:GetService("RunService")
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
    local timer = label(UDim2.fromScale(0.42, 0.085))
    timer.Size = UDim2.fromScale(0.16, 0.06)
    timer.TextColor3 = Color3.fromRGB(255, 220, 80)
    timer.Visible = false
    local fuel = label(UDim2.fromScale(0.02, 0.9))
    fuel.Size = UDim2.fromScale(0.16, 0.05)
    fuel.TextColor3 = Color3.fromRGB(255, 150, 60)
    fuel.Visible = false

    local RoundService = Knit.GetService("RoundService")
    local deadline = nil
    RoundService.StateChanged:Connect(function(s, data)
        local text = s
        if s == "Lobby" then
            text = "Stand on a pad to queue"
        elseif data.Mode then
            text = data.Mode .. "  " .. s
        end
        if s == "Intermission" and data.Map then
            text = ("%s  Next map: %s"):format(data.Mode or "", data.Map)
            -- Hero view: hold the camera on the map's vista for a couple of seconds
            if data.Vista then
                local cam = workspace.CurrentCamera
                local v = data.Vista
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = CFrame.lookAt(
                    Vector3.new(v.pos[1], v.pos[2], v.pos[3]),
                    Vector3.new(v.look[1], v.look[2], v.look[3])
                )
                local tween = game:GetService("TweenService"):Create(
                    cam,
                    TweenInfo.new(v.seconds or 2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { CFrame = cam.CFrame * CFrame.new(6, -2, 0) }
                )
                tween:Play()
                task.delay(math.min((v.seconds or 2.5), (data.Time or 5) - 0.5), function()
                    if cam.CameraType == Enum.CameraType.Scriptable then
                        cam.CameraType = Enum.CameraType.Custom
                    end
                end)
            end
        end
        -- Convergence has its own top bar; keep this label out of the way during play
        state.Visible = not (data.Mode == "Convergence" and s == "Round")
        -- Countdown for any state that carries a Time (Intermission, Round)
        if data.Time then
            deadline = os.clock() + data.Time
            timer.Visible = true
        else
            deadline = nil
            timer.Visible = false
        end
        if data.Winner then
            text ..= " - " .. data.Winner .. " wins"
        end
        if data.Score then
            text ..= "  Red " .. data.Score.Red .. " - " .. data.Score.Blue .. " Blue"
        end
        state.Text = text
    end)

    RunService.RenderStepped:Connect(function()
        if deadline then
            local left = math.max(0, deadline - os.clock())
            timer.Text = ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
        end
        local character = Players.LocalPlayer.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        if tool and tool.Name == "Jetpack" then
            fuel.Visible = true
            fuel.Text = ("FUEL  %d"):format(tool:GetAttribute("Fuel") or 0)
        else
            fuel.Visible = false
        end
    end)
end

return HudController
