-- Minimal HUD: round state, score, ammo. Replace with real UI later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudController = Knit.CreateController({ Name = "HudController" })

-- Slowly spin the kiosk showcase weapon so it catches the eye
-- Lobby nameplates: a flame + status for anyone on a visible streak (Phase 1 visibility)
local function streakNameplates()
    local RunService = game:GetService("RunService")
    local plates = {}
    RunService.Heartbeat:Connect(function()
        if os.clock() - (plates._t or 0) < 1 then
            return
        end
        plates._t = os.clock()
        for _, p in Players:GetPlayers() do
            local status = p:GetAttribute("StreakStatus")
            local head = p.Character and p.Character:FindFirstChild("Head")
            if status and status ~= "" and head and p ~= Players.LocalPlayer then
                local bb = plates[p]
                if not bb or bb.Parent ~= head then
                    bb = Instance.new("BillboardGui")
                    bb.Name = "StreakPlate"
                    bb.Size = UDim2.fromOffset(200, 30)
                    bb.StudsOffset = Vector3.new(0, 2.6, 0)
                    bb.AlwaysOnTop = true
                    bb.MaxDistance = 90
                    bb.Parent = head
                    local l = Instance.new("TextLabel")
                    l.Size = UDim2.fromScale(1, 1)
                    l.BackgroundTransparency = 1
                    l.TextScaled = true
                    l.Font = Enum.Font.GothamBold
                    l.TextColor3 = Theme.Color.Warn
                    Theme.overWorld(l)
                    l.Parent = bb
                    plates[p] = bb
                end
                bb.TextLabel.Text = ("🔥 %s (%d)"):format(status, p:GetAttribute("CurrentStreak") or 0)
            elseif plates[p] then
                plates[p]:Destroy()
                plates[p] = nil
            end
        end
    end)
end

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
    streakNameplates()
    local gui = Screen.newScreenGui("Hud", Screen.Layers.Hud)
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

    local function label(pos)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.fromScale(0.3, 0.06)
        l.Position = pos
        -- 0.4 put muted text at 2.8:1 over a bright sky; Theme holds it at 5.8:1.
        l.BackgroundTransparency = Theme.Transparency.Panel
        l.BackgroundColor3 = Color3.new(0, 0, 0)
        l.TextColor3 = Color3.new(1, 1, 1)
        l.TextScaled = true
        l.Font = Enum.Font.GothamBold
        l.Parent = gui
        return l
    end
    local state = label(UDim2.fromScale(0.35, 0.02))
    state.AnchorPoint = Vector2.new(0.5, 0)
    -- Pickup and safety toasts. They used to sit under the round state in the top centre, which
    -- on a phone is exactly where the Convergence zone chips are and just above the crosshair.
    -- The left edge, between the Roblox topbar and the movement thumbstick, is free on every
    -- device, and a toast there never covers the fight.
    local toast = label(UDim2.fromScale(0.35, 0.16))
    toast.Size = UDim2.fromScale(0.3, 0.05)
    toast.AnchorPoint = Vector2.new(0, 0)
    toast.TextXAlignment = Enum.TextXAlignment.Left
    toast.TextColor3 = Theme.Color.Accent
    toast.Visible = false
    local toastToken = 0
    Knit.GetService("SafetyService").Notice:Connect(function(text)
        toast.Text = text
        toast.Visible = true
        toastToken += 1
        local mine = toastToken
        task.delay(2.5, function()
            if toastToken == mine then
                toast.Visible = false
            end
        end)
    end)
    Knit.GetService("PickupService").Notice:Connect(function(text)
        toast.Text = text
        toast.Visible = true
        toastToken += 1
        local mine = toastToken
        task.delay(1.6, function()
            if toastToken == mine then
                toast.Visible = false
            end
        end)
    end)
    -- mild camera rumble for flyovers / kraken
    Knit.GetService("AmbientService").Rumble:Connect(function(strength, seconds)
        local cam = workspace.CurrentCamera
        local t0 = os.clock()
        local conn
        conn = game:GetService("RunService").RenderStepped:Connect(function()
            local t = os.clock() - t0
            if t > seconds then
                conn:Disconnect()
                return
            end
            local k = strength * (1 - t / seconds)
            cam.CFrame = cam.CFrame
                * CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
        end)
    end)
    local RunService = game:GetService("RunService")
    local timer = label(UDim2.fromScale(0.42, 0.085))
    timer.Size = UDim2.fromScale(0.16, 0.06)
    timer.AnchorPoint = Vector2.new(0.5, 0)
    timer.TextColor3 = Theme.Color.Accent
    timer.Visible = false
    local fuel = label(UDim2.fromScale(0.02, 0.9))
    fuel.Size = UDim2.fromScale(0.16, 0.05)
    fuel.TextColor3 = Theme.Color.Warn
    fuel.Visible = false

    -- All four readouts are re-anchored whenever the screen changes. The rules: hang off the
    -- safe-area inset rather than the raw screen edge, keep out of Screen.Aim (the middle
    -- of the screen), and on touch keep out of the bottom corners, which belong to Roblox's
    -- thumbstick, jump button and the Weapons Kit fire button.
    Screen.onChange(function(view)
        local topY = view.Insets.Top
        state.Position = UDim2.new(0.5, 0, 0, topY)
        -- AbsoluteSize is still 0 on the first frame, so derive the row height from the viewport.
        timer.Position = UDim2.new(0.5, 0, 0, topY + math.floor(view.Viewport.Y * 0.06) + 4)
        toast.Position = UDim2.new(0, view.Insets.Left, 0.30, 0)
        toast.Size = UDim2.fromScale(view.Touch and 0.34 or 0.26, 0.05)
        if view.Touch then
            -- bottom-left is the movement thumbstick; sit above it on the same edge
            fuel.Position = UDim2.new(0, view.Insets.Left, 0.40, 0)
        else
            fuel.Position = UDim2.new(0, view.Insets.Left, 1, -view.Insets.Bottom - 40)
        end
        fuel.Size = UDim2.fromScale(view.Touch and 0.22 or 0.16, 0.05)
    end)

    local RoundService = Knit.GetService("RoundService")
    local deadline = nil
    RoundService.StateChanged:Connect(function(s, data)
        local text = s
        if s == "Lobby" then
            text = "Choose PLAY or enter the arena gate"
        elseif data.Mode then
            text = data.Mode .. "  " .. s
        end
        if s == "Intermission" and data.Map then
            text = ("%s  Next map: %s"):format(data.Mode or "", data.Map)
            local wanted = {}
            for _, p in Players:GetPlayers() do
                if p:GetAttribute("InMatch") and (p:GetAttribute("CurrentStreak") or 0) >= 3 then
                    table.insert(
                        wanted,
                        ("%s (%d-match streak, %s)"):format(
                            p.Name,
                            p:GetAttribute("CurrentStreak"),
                            p:GetAttribute("StreakStatus") or ""
                        )
                    )
                end
            end
            if #wanted > 0 then
                text = text .. "\nWANTED: " .. table.concat(wanted, "  ·  ")
            end
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
