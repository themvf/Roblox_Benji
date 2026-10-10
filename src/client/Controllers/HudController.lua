-- The top of the screen, Rivals-style: one score bar during a Duel round (red score, clock,
-- blue score, your side underlined), one status line in the lobby and between rounds, and
-- one notice line under them that every other system announces through -- pickups, safety,
-- mutation, bounties, zone events. Convergence owns the top during its rounds, so this
-- whole stack steps aside then and only the notice line stays.
--
-- Notices are an icon and a few words, never an instruction sentence: "SPEED" with a bolt,
-- not "SPEED BOOST picked up, press Shift". Health, ammo and the hotbar live at the bottom
-- (VitalsController, WeaponBarController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Icons = require(script.Parent.Parent.UI.Icons)

local HudController = Knit.CreateController({ Name = "HudController" })

local PANEL = Theme.Color.Panel
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local ACCENT = Theme.Color.Accent

-- Server notices arrive as plain text; the icon is picked from what they say.
local NOTICE_ICONS = {
    { "SPEED", "Speed" },
    { "JETPACK", "Fuel" },
    { "PICKED UP", "Ammo" },
    { "EXPIRED", "Ammo" },
    { "RECOVERED", "Info" },
    { "OUT OF BOUNDS", "Info" },
}

local function noticeIcon(text)
    local upper = text:upper()
    for _, pair in NOTICE_ICONS do
        if upper:find(pair[1], 1, true) then
            return pair[2]
        end
    end
    return "Info"
end

-- Lobby nameplates: a flame + status for anyone on a visible streak (Phase 1 visibility)
local function streakNameplates()
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

-- Slowly spin the kiosk showcase weapon so it catches the eye
local function spinShowcase()
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

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = inst
end

local function text(parent, size, font, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.TextSize = Theme.textSize(size)
    l.Font = font
    l.TextColor3 = color
    l.Text = ""
    l.Parent = parent
    return l
end

function HudController:BuildScoreBar(gui)
    -- Duel score bar. Your team is the underlined side, so it reads without colour too.
    local bar = Instance.new("Frame")
    bar.Name = "ScoreBar"
    bar.AnchorPoint = Vector2.new(0.5, 0)
    bar.Size = UDim2.fromOffset(280, 48)
    bar.BackgroundColor3 = PANEL
    bar.BackgroundTransparency = Theme.Transparency.Panel
    bar.Visible = false
    bar.Parent = gui
    corner(bar, 12)
    Screen.autoScale(bar)
    self.ScoreBar = bar

    local function side(x, team)
        local l = text(bar, Theme.Type.Display, Enum.Font.GothamBlack, Theme.team(team))
        l.Position = UDim2.fromScale(x, 0)
        l.Size = UDim2.fromScale(0.3, 1)
        l.Text = "0"
        local mark = Instance.new("Frame")
        mark.AnchorPoint = Vector2.new(0.5, 1)
        mark.Position = UDim2.new(0.5, 0, 1, -5)
        mark.Size = UDim2.fromOffset(30, 4)
        mark.BackgroundColor3 = Theme.team(team)
        mark.BorderSizePixel = 0
        mark.Visible = false
        mark.Parent = l
        corner(mark, 2)
        return l, mark
    end
    self.RedScore, self.RedMark = side(0.02, "Red")
    self.BlueScore, self.BlueMark = side(0.68, "Blue")

    local clock = text(bar, Theme.Type.Title, Enum.Font.GothamBlack, TEXT)
    clock.Position = UDim2.fromScale(0.3, 0)
    clock.Size = UDim2.fromScale(0.4, 1)
    self.Clock = clock
end

function HudController:BuildStatus(gui)
    -- Lobby and between rounds: one line, e.g. "NEXT MAP  SNOW FORTRESS  0:05".
    local status = text(gui, Theme.Type.Body, Enum.Font.GothamBold, TEXT)
    status.Name = "Status"
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.AutomaticSize = Enum.AutomaticSize.X
    status.Size = UDim2.fromOffset(0, 34)
    status.BackgroundColor3 = PANEL
    status.BackgroundTransparency = Theme.Transparency.Panel
    status.Visible = false
    corner(status, 10)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = status
    Screen.autoScale(status)
    self.Status = status
end

function HudController:BuildNotice(gui)
    -- An icon and a few stroked words above the crosshair, no panel: a dark box in the middle
    -- of the screen is a sight blocker, a word is not.
    local notice = Instance.new("Frame")
    notice.Name = "Notice"
    notice.AnchorPoint = Vector2.new(0.5, 0)
    notice.AutomaticSize = Enum.AutomaticSize.X
    notice.Size = UDim2.fromOffset(0, 32)
    notice.BackgroundTransparency = 1
    notice.Visible = false
    notice.Parent = gui
    Screen.autoScale(notice)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = notice

    local iconHolder = Instance.new("Frame")
    iconHolder.Size = UDim2.fromOffset(28, 28)
    iconHolder.BackgroundTransparency = 1
    iconHolder.LayoutOrder = 1
    iconHolder.Parent = notice
    local icon = Icons.make(iconHolder, "Info")
    if icon:IsA("TextLabel") then
        Theme.overWorld(icon) -- a UIStroke on an ImageLabel would outline its box, not the glyph
    end

    local label = text(notice, Theme.Type.Title, Enum.Font.GothamBlack, ACCENT)
    label.LayoutOrder = 2
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, 32)
    Theme.overWorld(label)

    self.Notice, self.NoticeIcon, self.NoticeLabel = notice, icon, label
    self.NoticeToken = 0
end

-- Announce something. `icon` is an Icons name; omitted, it is inferred from the text.
function HudController:Notify(message: string, color: Color3?, icon: string?, seconds: number?)
    if not self.Notice then
        return
    end
    color = color or ACCENT
    Icons.set(self.NoticeIcon, icon or noticeIcon(message))
    Icons.tint(self.NoticeIcon, color)
    self.NoticeLabel.Text = message:upper()
    self.NoticeLabel.TextColor3 = color
    self.NoticeLabel.TextTransparency = 0
    self.Notice.Visible = true
    self.NoticeToken += 1
    local token = self.NoticeToken
    task.delay(seconds or 1.8, function()
        if self.NoticeToken ~= token then
            return
        end
        TweenService:Create(self.NoticeLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
        task.delay(0.3, function()
            if self.NoticeToken == token then
                self.Notice.Visible = false
            end
        end)
    end)
end

-- Lay the stack out top-down from the safe area. The notice goes under whichever bar is up:
-- the Convergence bar and its zone chips are taller than the Duel score bar.
function HudController:Layout()
    local state = Screen.get()
    local k = state.Scale
    local topY = state.Insets.Top
    self.ScoreBar.Position = UDim2.new(0.5, 0, 0, topY)
    self.Status.Position = UDim2.new(0.5, 0, 0, topY)
    local conv = Knit.GetController("ConvergenceController")
    local below
    if conv.Gui and conv.Gui.Enabled then
        below = topY + math.floor(102 * k) + 8
    elseif self.ScoreBar.Visible then
        below = topY + math.floor(48 * k) + 8
    elseif self.Status.Visible then
        below = topY + math.floor(34 * k) + 8
    else
        below = topY + 8
    end
    self.Notice.Position = UDim2.new(0.5, 0, 0, below)
end

function HudController:ApplyTeam()
    local team = Players.LocalPlayer:GetAttribute("Team")
    self.RedMark.Visible = team == "Red"
    self.BlueMark.Visible = team == "Blue"
end

function HudController:OnState(s, data)
    local convergence = data.Mode == "Convergence"
    self.Deadline = data.Time and (os.clock() + data.Time) or nil
    self.StatusText = nil

    if data.Score then
        self.RedScore.Text = tostring(math.floor(data.Score.Red))
        self.BlueScore.Text = tostring(math.floor(data.Score.Blue))
    end
    -- Duel rounds get the score bar; Convergence rounds have their own bar.
    self.ScoreBar.Visible = not convergence and (s == "Round" or s == "RoundOver")
    self.Clock.Text = ""

    if s == "Lobby" then
        self.StatusText = "CHOOSE PLAY OR ENTER THE ARENA GATE"
    elseif s == "Intermission" then
        self.StatusText = data.Map and ("NEXT MAP  " .. (data.Map:gsub("(%l)(%u)", "%1 %2")):upper()) or "GET READY"
        local wanted = {}
        for _, p in Players:GetPlayers() do
            if p:GetAttribute("InMatch") and (p:GetAttribute("CurrentStreak") or 0) >= 3 then
                table.insert(wanted, p.Name)
            end
        end
        if #wanted > 0 then
            self:Notify("WANTED  " .. table.concat(wanted, ", "), Theme.Color.Warn, "Info", 4)
        end
        self:PlayVista(data)
    elseif s == "RoundOver" and data.Winner then
        self:Notify(data.Winner .. " WINS THE ROUND", Theme.team(data.Winner), "Zone", 3)
    elseif s == "MatchOver" and not data.Aborted and data.Score then
        local red, blue = data.Score.Red, data.Score.Blue
        local winner = red > blue and "Red" or (blue > red and "Blue" or nil)
        self.StatusText = winner and (winner:upper() .. " WINS") or "DRAW"
    end
    self.Status.Visible = self.StatusText ~= nil
    self.Status.Text = self.StatusText or ""
    self:ApplyTeam()
    self:Layout()
end

-- Hero view: hold the camera on the map's vista for a couple of seconds
function HudController:PlayVista(data)
    local v = data.Vista
    if not v then
        return
    end
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Scriptable
    cam.CFrame = CFrame.lookAt(Vector3.new(v.pos[1], v.pos[2], v.pos[3]), Vector3.new(v.look[1], v.look[2], v.look[3]))
    local tween = TweenService:Create(
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

function HudController:KnitStart()
    spinShowcase()
    streakNameplates()
    local gui = Screen.newScreenGui("Hud", Screen.Layers.Hud)
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self:BuildScoreBar(gui)
    self:BuildStatus(gui)
    self:BuildNotice(gui)
    Screen.onChange(function()
        self:Layout()
    end)

    Knit.GetService("SafetyService").Notice:Connect(function(message)
        self:Notify(message, MUTED)
    end)
    Knit.GetService("PickupService").Notice:Connect(function(message)
        self:Notify(message, ACCENT)
    end)
    -- mild camera rumble for flyovers / kraken
    Knit.GetService("AmbientService").Rumble:Connect(function(strength, seconds)
        local cam = workspace.CurrentCamera
        local t0 = os.clock()
        local conn
        conn = RunService.RenderStepped:Connect(function()
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

    Knit.GetService("RoundService").StateChanged:Connect(function(s, data)
        self:OnState(s, data or {})
    end)
    Players.LocalPlayer:GetAttributeChangedSignal("Team"):Connect(function()
        self:ApplyTeam()
    end)

    local lastLayout = 0
    RunService.RenderStepped:Connect(function()
        if self.Deadline then
            local left = math.max(0, self.Deadline - os.clock())
            local clock = ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
            self.Clock.Text = clock
            if self.StatusText then
                self.Status.Text = self.StatusText .. "  " .. clock
            end
        end
        -- the Convergence bar appears on its own schedule; re-seat the notice a few times a second
        if os.clock() - lastLayout > 0.25 then
            lastLayout = os.clock()
            self:Layout()
        end
    end)
end

return HudController
