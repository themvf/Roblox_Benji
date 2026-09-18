-- Convergence HUD: team scores, phase and clock, one chip per zone with owner colour and
-- capture bar, plus event banners (captures, zone closing, phase change, overtime).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ConvergenceController = Knit.CreateController({ Name = "ConvergenceController" })

local RED = Color3.fromRGB(255, 70, 70)
local BLUE = Color3.fromRGB(70, 140, 255)
local NEUTRAL = Color3.fromRGB(200, 200, 205)
local CLOSED = Color3.fromRGB(80, 80, 85)
local PANEL = Color3.fromRGB(20, 22, 28)
local TEXT = Color3.fromRGB(245, 245, 250)
local ACCENT = Color3.fromRGB(255, 200, 70)

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = inst
end

local function teamColor(team)
    if team == "Red" then
        return RED
    elseif team == "Blue" then
        return BLUE
    end
    return NEUTRAL
end

function ConvergenceController:BuildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ConvergenceHud"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    -- Top bar: RED score | phase + clock | BLUE score
    local top = Instance.new("Frame")
    top.AnchorPoint = Vector2.new(0.5, 0)
    top.Position = UDim2.new(0.5, 0, 0, 8)
    top.Size = UDim2.fromOffset(420, 54)
    top.BackgroundColor3 = PANEL
    top.BackgroundTransparency = 0.25
    top.Parent = gui
    corner(top, 12)

    local function score(x, color, align)
        local l = Instance.new("TextLabel")
        l.Position = UDim2.new(x, 0, 0, 0)
        l.Size = UDim2.new(0.3, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = "0"
        l.TextSize = 30
        l.Font = Enum.Font.GothamBlack
        l.TextColor3 = color
        l.TextXAlignment = align
        l.Parent = top
        return l
    end
    self.RedScore = score(0.03, RED, Enum.TextXAlignment.Left)
    self.BlueScore = score(0.67, BLUE, Enum.TextXAlignment.Right)

    local mid = Instance.new("TextLabel")
    mid.Position = UDim2.new(0.33, 0, 0, 4)
    mid.Size = UDim2.new(0.34, 0, 0, 22)
    mid.BackgroundTransparency = 1
    mid.Text = "PHASE 1"
    mid.TextSize = 14
    mid.Font = Enum.Font.GothamBold
    mid.TextColor3 = ACCENT
    mid.Parent = top
    self.PhaseLabel = mid
    local clock = Instance.new("TextLabel")
    clock.Position = UDim2.new(0.33, 0, 0, 24)
    clock.Size = UDim2.new(0.34, 0, 0, 26)
    clock.BackgroundTransparency = 1
    clock.Text = "3:00"
    clock.TextSize = 22
    clock.Font = Enum.Font.GothamBlack
    clock.TextColor3 = TEXT
    clock.Parent = top
    self.Clock = clock

    -- Zone chips under the bar
    local row = Instance.new("Frame")
    row.AnchorPoint = Vector2.new(0.5, 0)
    row.Position = UDim2.new(0.5, 0, 0, 68)
    row.Size = UDim2.fromOffset(420, 40)
    row.BackgroundTransparency = 1
    row.Parent = gui
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = row
    self.ZoneRow = row
    self.Chips = {}

    -- Banner
    local banner = Instance.new("TextLabel")
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.Position = UDim2.new(0.5, 0, 0.2, 0)
    banner.Size = UDim2.fromOffset(520, 44)
    banner.BackgroundColor3 = PANEL
    banner.BackgroundTransparency = 0.3
    banner.Text = ""
    banner.TextSize = 24
    banner.Font = Enum.Font.GothamBlack
    banner.TextColor3 = ACCENT
    banner.Visible = false
    banner.Parent = gui
    corner(banner, 10)
    self.Banner = banner
end

function ConvergenceController:Chip(name)
    local chip = self.Chips[name]
    if chip then
        return chip
    end
    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(130, 40)
    f.BackgroundColor3 = PANEL
    f.BackgroundTransparency = 0.25
    f.LayoutOrder = #self.ZoneRow:GetChildren()
    f.Parent = self.ZoneRow
    corner(f, 8)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = TEXT
    label.Parent = f
    local back = Instance.new("Frame")
    back.Position = UDim2.new(0.08, 0, 0, 26)
    back.Size = UDim2.new(0.84, 0, 0, 8)
    back.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
    back.BorderSizePixel = 0
    back.Parent = f
    corner(back, 4)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromScale(0, 1)
    bar.BackgroundColor3 = NEUTRAL
    bar.BorderSizePixel = 0
    bar.Parent = back
    corner(bar, 4)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = NEUTRAL
    stroke.Parent = f
    chip = { Frame = f, Label = label, Bar = bar, Stroke = stroke }
    self.Chips[name] = chip
    return chip
end

function ConvergenceController:Apply(snap)
    self.Gui.Enabled = true
    self.RedScore.Text = tostring(math.floor(snap.Score.Red))
    self.BlueScore.Text = tostring(math.floor(snap.Score.Blue))
    local left = math.max(0, snap.PhaseTimeLeft or 0)
    if snap.Overtime then
        self.PhaseLabel.Text = "OVERTIME"
        self.Clock.Text = "FINAL ZONE"
    else
        local zonesLive = 0
        for _, z in snap.Zones do
            if z.Live and not z.Closed then
                zonesLive += 1
            end
        end
        self.PhaseLabel.Text = ("PHASE %d   %d ZONE%s"):format(snap.Phase, zonesLive, zonesLive == 1 and "" or "S")
        self.Clock.Text = ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
    end
    for _, z in snap.Zones do
        local chip = self:Chip(z.Name)
        local color = z.Closed and CLOSED or teamColor(z.Owner)
        chip.Stroke.Color = z.Contested and ACCENT or color
        chip.Label.TextColor3 = z.Closed and CLOSED or TEXT
        chip.Label.Text = z.Closed and (z.Name .. " (closed)") or z.Name
        chip.Bar.BackgroundColor3 = teamColor(z.Capturing or z.Owner)
        chip.Bar.Size = UDim2.fromScale(z.Closed and 0 or math.clamp((z.Progress or 0) / 100, 0, 1), 1)
        chip.Frame.BackgroundTransparency = z.Closed and 0.6 or 0.25
    end
end

function ConvergenceController:ShowBanner(text, color)
    local b = self.Banner
    b.Text = text
    b.TextColor3 = color or ACCENT
    b.Visible = true
    b.TextTransparency = 0
    b.BackgroundTransparency = 0.3
    if self.BannerToken then
        self.BannerToken = self.BannerToken + 1
    else
        self.BannerToken = 1
    end
    local token = self.BannerToken
    task.delay(2.2, function()
        if self.BannerToken ~= token then
            return
        end
        TweenService:Create(b, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
        task.delay(0.4, function()
            if self.BannerToken == token then
                b.Visible = false
            end
        end)
    end)
end

function ConvergenceController:KnitStart()
    self:BuildGui()
    local svc = Knit.GetService("ConvergenceService")
    svc.State:Connect(function(snap)
        self:Apply(snap)
    end)
    svc.Event:Connect(function(kind, data)
        if kind == "ZoneCaptured" then
            self:ShowBanner((data.Team or ""):upper() .. " CAPTURED " .. data.Zone:upper(), teamColor(data.Team))
        elseif kind == "ZoneNeutralized" then
            self:ShowBanner(data.Zone:upper() .. " NEUTRALIZED", NEUTRAL)
        elseif kind == "ZoneClosing" then
            self:ShowBanner(data.Zone:upper() .. " CLOSING IN " .. data.Seconds .. "s", ACCENT)
        elseif kind == "ZoneClosed" then
            self:ShowBanner(data.Zone:upper() .. " CLOSED", CLOSED)
        elseif kind == "Phase" then
            self:ShowBanner(
                ("PHASE %d   %d ZONE%s"):format(data.Phase, data.Zones, data.Zones == 1 and "" or "S"),
                ACCENT
            )
        elseif kind == "MapEventWarning" then
            self:ShowBanner(
                (data.Banner or data.Name:upper()) .. "  " .. tostring(data.Seconds) .. "s",
                Color3.fromRGB(255, 90, 50)
            )
        elseif kind == "MapEventStart" then
            self:ShowBanner(data.Banner or data.Name:upper(), Color3.fromRGB(255, 90, 50))
        elseif kind == "MapEventEnd" then
            self:ShowBanner(data.Name:upper() .. " CLEAR", NEUTRAL)
        elseif kind == "Overtime" then
            self:ShowBanner("OVERTIME", ACCENT)
        end
    end)
    -- hide when the round system says we're back in the lobby or in a Duel
    Knit.GetService("RoundService").StateChanged:Connect(function(state, data)
        if state == "Lobby" or (data and data.Mode and data.Mode ~= "Convergence") then
            self.Gui.Enabled = false
        end
    end)
end

return ConvergenceController
