-- Convergence HUD: team scores, phase and clock, one chip per zone with owner colour and
-- capture bar, plus event banners (captures, zone closing, phase change, overtime).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local ConvergenceController = Knit.CreateController({ Name = "ConvergenceController" })

-- Team colours and surfaces come from Theme, so the top bar, the scoreboard and the world
-- cannot drift apart again.
local RED = Theme.Team.Red
local BLUE = Theme.Team.Blue
local NEUTRAL = Theme.Team.Neutral
local CLOSED = Theme.Team.Closed
local PANEL = Theme.Color.Panel
local TEXT = Theme.Color.Text
local ACCENT = Theme.Color.Accent
local MUTED_ACCENT = Theme.Color.TextMuted

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
    local gui = Screen.newScreenGui("ConvergenceHud", Screen.Layers.Objective)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    -- Container for the whole objective readout. It is NOT scaled itself: a UIScale on a
    -- full-screen frame would move the 0.5 centre line, so each panel below carries its own
    -- UIScale (which scales about its own centre anchor) and is positioned in screen pixels.
    local root = Instance.new("Frame")
    root.Name = "Root"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromScale(1, 1)
    root.Parent = gui

    -- Top bar: RED score | phase + clock | BLUE score
    -- One line, not three: "RED 47 | PHASE 1 . 1:24 | 0 BLUE". Vertical space at the top of the
    -- screen is sightline, and the player is usually aiming through it.
    local top = Instance.new("Frame")
    top.AnchorPoint = Vector2.new(0.5, 0)
    top.Size = UDim2.fromOffset(420, 54)
    top.BackgroundColor3 = PANEL
    top.BackgroundTransparency = Theme.Transparency.Panel
    top.Parent = root
    self.TopBar = top
    corner(top, 12)

    local function score(x, color, align)
        local l = Instance.new("TextLabel")
        l.Position = UDim2.new(x, 0, 0, 0)
        l.Size = UDim2.new(0.3, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = "0"
        l.TextSize = Theme.textSize(Theme.Type.Display)
        l.Font = Enum.Font.GothamBlack
        l.TextColor3 = color
        l.TextXAlignment = align
        l.Parent = top
        return l
    end
    self.RedScore = score(0.03, RED, Enum.TextXAlignment.Left)
    self.BlueScore = score(0.67, BLUE, Enum.TextXAlignment.Right)
    -- your side is underlined, so it reads without colour (it replaced the RED TEAM badge)
    local function mark(x, color)
        local m = Instance.new("Frame")
        m.AnchorPoint = Vector2.new(0, 1)
        m.Position = UDim2.new(x, 0, 1, -5)
        m.Size = UDim2.fromOffset(30, 4)
        m.BackgroundColor3 = color
        m.BorderSizePixel = 0
        m.Visible = false
        m.Parent = top
        corner(m, 2)
        return m
    end
    self.RedMark = mark(0.03, RED)
    self.BlueMark = mark(0.97, BLUE)
    self.BlueMark.AnchorPoint = Vector2.new(1, 1)

    -- phase is context, the clock is the thing you glance at: one line, clock weighted heavier
    local mid = Instance.new("TextLabel")
    mid.Position = UDim2.new(0.30, 0, 0, 0)
    mid.Size = UDim2.new(0.40, 0, 1, 0)
    mid.BackgroundTransparency = 1
    mid.Text = "PHASE 1"
    mid.TextSize = Theme.textSize(Theme.Type.Label)
    mid.Font = Enum.Font.GothamBold
    mid.TextColor3 = MUTED_ACCENT
    mid.TextXAlignment = Enum.TextXAlignment.Left
    mid.Parent = top
    self.PhaseLabel = mid
    local clock = Instance.new("TextLabel")
    clock.Position = UDim2.new(0.30, 0, 0, 0)
    clock.Size = UDim2.new(0.40, 0, 1, 0)
    clock.BackgroundTransparency = 1
    clock.Text = "3:00"
    clock.TextSize = Theme.textSize(Theme.Type.Title)
    clock.Font = Enum.Font.GothamBlack
    clock.TextColor3 = TEXT
    clock.TextXAlignment = Enum.TextXAlignment.Right
    clock.Parent = top
    self.Clock = clock

    -- Zone chips under the bar
    local row = Instance.new("Frame")
    row.AnchorPoint = Vector2.new(0.5, 0)
    row.Size = UDim2.fromOffset(420, 40)
    row.BackgroundTransparency = 1
    row.Parent = root
    self.ZoneRowFrame = row
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = row
    self.ZoneRow = row
    local final = Instance.new("TextLabel")
    final.Name = "FinalDistrict"
    final.AnchorPoint = Vector2.new(0.5, 0)
    final.Position = UDim2.new(0.5, 0, 0, 88)
    final.Size = UDim2.fromOffset(320, 28)
    final.BackgroundColor3 = PANEL
    final.BackgroundTransparency = 0.1
    final.TextColor3 = ACCENT
    final.Font = Enum.Font.GothamBold
    final.TextSize = 12
    final.TextWrapped = true
    final.Visible = false
    final.Parent = gui
    corner(final, 8)
    self.FinalLabel = final
    self.Chips = {}

    -- Announcements go through the HUD's one notice line (HudController:Notify), which seats
    -- itself under this stack. The stack is laid out top-down from the safe-area inset and
    -- re-laid out on every screen change, so the bar and the chips never overlap each other or
    -- drift under the topbar.
    Screen.autoScale(top)
    Screen.autoScale(row)
    Screen.onChange(function(state)
        local k = state.Scale
        local topY = state.Insets.Top
        top.Position = UDim2.new(0.5, 0, 0, topY)
        row.Position = UDim2.new(0.5, 0, 0, topY + math.floor(54 * k) + 8)
        final.Size = UDim2.fromOffset(math.min(320, state.Viewport.X - 32), 28)
        final.Position = UDim2.new(0.5, 0, 0, topY + math.floor(94 * k) + 10)
    end)
end

-- Notices name a zone by the same letter its chip shows, so "RED CAPTURED B" points at a chip
-- the player can see. (The world keeps its shapes; the HUD speaks letters.)
local ZONE_LETTER = { "A", "B", "C", "D" }

local function glyphChar(index)
    return ZONE_LETTER[index or 0] or "?"
end

-- shared with other controllers (bounty pings) so there is one vocabulary, not two
function ConvergenceController:GlyphChar(index)
    return glyphChar(index)
end

-- The 2D twin of the world glyph (ConvergenceService.GLYPH_SHAPE): square, diamond, circle.
-- Objectives carry no names anywhere, so the HUD has to teach the same vocabulary the world uses.
local LETTER = { "A", "B", "C", "D" }

local function glyphIcon(parent, index, size)
    local holder = Instance.new("Frame")
    holder.Name = "Glyph"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromOffset(size, size)
    holder.Parent = parent

    -- A/B/C, not a shape to decode. The shape vocabulary stays on the physical objectives in the
    -- world, where it is the object; in the HUD a letter is understood with no learning at all.
    local shape = Instance.new("TextLabel")
    shape.Name = "Shape"
    shape.AnchorPoint = Vector2.new(0.5, 0.5)
    shape.Position = UDim2.fromScale(0.5, 0.5)
    shape.Size = UDim2.fromOffset(size, size)
    shape.BackgroundTransparency = 1
    shape.Text = LETTER[index] or tostring(index)
    shape.TextSize = math.floor(size * 0.95)
    shape.Font = Enum.Font.GothamBlack
    shape.TextColor3 = Color3.new(1, 1, 1)
    shape.Parent = holder
    return holder, shape
end

-- pip row: the same count the world shows under each objective
local function pipRow(parent, index, dotSize)
    local row = Instance.new("Frame")
    row.Name = "Pips"
    row.BackgroundTransparency = 1
    row.Size = UDim2.fromOffset(index * (dotSize + 2), dotSize)
    row.Parent = parent
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 2)
    layout.Parent = row
    local dots = {}
    for i = 1, index do
        local d = Instance.new("Frame")
        d.Name = "Pip" .. i
        d.Size = UDim2.fromOffset(dotSize, dotSize)
        d.BackgroundColor3 = Color3.new(1, 1, 1)
        d.BorderSizePixel = 0
        d.LayoutOrder = i
        d.Parent = row
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0.5, 0)
        c.Parent = d
        table.insert(dots, d)
    end
    return row, dots
end

function ConvergenceController:Chip(index)
    local chip = self.Chips[index]
    if chip then
        return chip
    end
    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(56, 38)
    f.BackgroundColor3 = PANEL
    f.BackgroundTransparency = Theme.Transparency.Panel
    f.LayoutOrder = #self.ZoneRow:GetChildren()
    f.Parent = self.ZoneRow
    corner(f, 8)
    local holder, shape = glyphIcon(f, index, 22)
    holder.Position = UDim2.fromOffset(4, 2)
    local pips, dots = pipRow(f, index, 4)
    pips.Visible = false -- the letter is the identity; pips were belt and braces
    local back = Instance.new("Frame")
    back.Position = UDim2.new(0.08, 0, 0, 26)
    back.Size = UDim2.new(0.84, 0, 0, 8)
    back.BackgroundColor3 = Theme.Color.Track
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
    chip = { Frame = f, Shape = shape, Dots = dots, Bar = bar, Stroke = stroke }
    local badge = Instance.new("TextLabel")
    badge.Position = UDim2.fromOffset(24, 3)
    badge.Size = UDim2.fromOffset(30, 17)
    badge.BackgroundTransparency = 1
    badge.Text = "FINAL"
    badge.TextSize = 9
    badge.Font = Enum.Font.GothamBlack
    badge.TextColor3 = ACCENT
    badge.Visible = false
    badge.Parent = f
    chip.FinalBadge = badge
    self.Chips[index] = chip
    return chip
end

function ConvergenceController:Apply(snap)
    self.ActiveMatchId = snap.MatchId
    self.Gui.Enabled = true
    self.RedScore.Text = tostring(math.floor(snap.Score.Red))
    self.BlueScore.Text = tostring(math.floor(snap.Score.Blue))
    local team = Players.LocalPlayer:GetAttribute("Team")
    self.RedMark.Visible = team == "Red"
    self.BlueMark.Visible = team == "Blue"
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
        self.PhaseLabel.Text = ("PHASE %d"):format(snap.Phase) -- the chips below already show how many are live
        -- Show the MATCH clock, not the phase clock. snap.TimeLeft was transmitted every tick and
        -- read by no client file, while the phase clock clamped to 0:00 for the whole final phase.
        -- How long the match has left is the thing a player actually needs; phase changes announce
        -- themselves with a banner.
        local matchLeft = math.max(0, snap.TimeLeft or left)
        self.Clock.Text = ("%d:%02d"):format(math.floor(matchLeft / 60), math.floor(matchLeft % 60))
    end
    self.FinalLabel.Visible = false
    for i, z in snap.Zones do
        local chip = self:Chip(z.Index or i)
        local color = z.Closed and CLOSED or teamColor(z.Owner)
        chip.Stroke.Color = z.Contested and ACCENT or color
        chip.Stroke.Thickness = z.IsFinal and 4 or 2
        chip.FinalBadge.Visible = z.IsFinal == true
        if z.IsFinal then
            self.FinalLabel.Visible = true
            self.FinalLabel.Text = "FINAL: " .. z.Name:upper()
        end
        -- closed reads as a dimmed, hollow glyph, matching how the world pillar goes dim
        chip.Shape.TextColor3 = z.Closed and CLOSED or color
        chip.Shape.TextTransparency = z.Closed and 0.45 or 0
        for _, d in chip.Dots do
            d.BackgroundColor3 = z.Closed and CLOSED or color
            d.BackgroundTransparency = z.Closed and 0.45 or 0
        end
        chip.Bar.BackgroundColor3 = teamColor(z.Capturing or z.Owner)
        chip.Bar.Size = UDim2.fromScale(z.Closed and 0 or math.clamp((z.Progress or 0) / 100, 0, 1), 1)
        chip.Frame.BackgroundTransparency = z.Closed and 0.6 or 0.25
    end
end

function ConvergenceController:RevealFinale(data)
    if self.RevealedMatchId == data.MatchId or (self.ActiveMatchId and data.MatchId < self.ActiveMatchId) then
        return
    end
    self.RevealedMatchId = data.MatchId
    self.FinalLabel.Text = "FINAL: " .. data.Name:upper()
    self.FinalLabel.Visible = true
    self:ShowBanner("FINAL DISTRICT: " .. data.Name:upper(), ACCENT, "Zone")
    local soundId = Uploads.resolve("upload:FinaleReveal_" .. data.Id) or Uploads.resolve("upload:FinaleReveal")
    if soundId then
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.7
        sound.Parent = SoundService
        sound:Play()
        Debris:AddItem(sound, 12)
    end
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    if tuning and tuning:GetAttribute("UI_ReducedMotion") == true then
        return -- persistent text and marker carry the reveal without motion or audio
    end
    local folder = workspace:FindFirstChild("Objectives")
    for _, object in folder and folder:GetChildren() or {} do
        if object:IsA("BasePart") and object:GetAttribute("ObjectiveId") == data.Id then
            local pulse = Instance.new("Highlight")
            pulse.Adornee = object
            pulse.FillTransparency = 1
            pulse.OutlineColor = ACCENT
            pulse.OutlineTransparency = 0
            pulse.Parent = object
            TweenService:Create(pulse, TweenInfo.new(1.5), { OutlineTransparency = 1 }):Play()
            Debris:AddItem(pulse, 1.6)
        end
    end
end

-- Kept as the name other controllers call (mutation, bounties); it now feeds the HUD's one
-- notice line, so a Duel shows these too -- the old banner lived in this gui, which is off
-- outside Convergence, and silently swallowed them.
function ConvergenceController:ShowBanner(text, color, icon)
    Knit.GetController("HudController"):Notify(text, color or ACCENT, icon)
end

function ConvergenceController:KnitStart()
    self:BuildGui()
    local svc = Knit.GetService("ConvergenceService")
    svc.State:Connect(function(snap)
        self:Apply(snap)
    end)
    svc.Event:Connect(function(kind, data)
        if kind == "FinaleRevealed" then
            self:RevealFinale(data)
        elseif kind == "ZoneCaptured" then
            self:ShowBanner(
                (data.Team or ""):upper() .. " CAPTURED " .. glyphChar(data.Index),
                teamColor(data.Team),
                "Zone"
            )
        elseif kind == "ZoneNeutralized" then
            self:ShowBanner(glyphChar(data.Index) .. " NEUTRALIZED", NEUTRAL, "Zone")
        elseif kind == "ZoneClosing" then
            self:ShowBanner(glyphChar(data.Index) .. " CLOSING IN " .. data.Seconds .. "s", ACCENT, "Zone")
        elseif kind == "ZoneClosed" then
            self:ShowBanner(glyphChar(data.Index) .. " CLOSED", CLOSED, "Zone")
        elseif kind == "Phase" then
            self:ShowBanner(
                ("PHASE %d   %d ZONE%s"):format(data.Phase, data.Zones, data.Zones == 1 and "" or "S"),
                ACCENT,
                "Zone"
            )
        elseif kind == "MapEventWarning" then
            self:ShowBanner(
                (data.Banner or data.Name:upper()) .. "  " .. tostring(data.Seconds) .. "s",
                Theme.Color.Danger,
                "Info"
            )
        elseif kind == "MapEventStart" then
            self:ShowBanner(data.Banner or data.Name:upper(), Theme.Color.Danger, "Info")
        elseif kind == "MapEventEnd" then
            self:ShowBanner(data.Name:upper() .. " CLEAR", NEUTRAL, "Info")
        elseif kind == "Overtime" then
            self:ShowBanner("OVERTIME", ACCENT, "Zone")
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
