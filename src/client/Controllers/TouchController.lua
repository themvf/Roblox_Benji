-- Touch HUD for phones and tablets. Draws big on-screen buttons for everything the desktop
-- build binds to keys: Mutate (Q), Ground Slam / Brace / Charge (E/F/C), hold-to-fly for the
-- jetpack, a scoreboard toggle (Tab) and the celebration skip vote (V). Guns already get a fire
-- button and drag-to-aim from the Weapons Kit, and movement/jump come from Roblox's own touch
-- controls, so those are not duplicated here. Only rendering and input: every action goes
-- through the same controller methods the keyboard uses, so the server sees identical requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local TouchController = Knit.CreateController({ Name = "TouchController" })

local PANEL = Theme.Color.Panel
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local READY = Theme.Color.Energy
local FLY = Theme.Color.Fly

local ABILITY_SHORT = { GroundSlam = "SLAM", Brace = "BRACE", Charge = "CHARGE" }

-- Touch device = a phone or tablet per Screen's device class (a laptop with a touchscreen keeps
-- its keyboard layout, an iPad with a Magic Keyboard stays a tablet).
-- Tuning.Debug_ForceTouchUi = true shows the touch HUD anywhere, so it can be checked in Studio
-- without the device emulator.
function TouchController.IsTouch()
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    if tuning and tuning:GetAttribute("Debug_ForceTouchUi") == true then
        return true
    end
    return Screen.isTouch()
end

local function round(inst)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = inst
end

local function stroke(inst, color)
    local s = Instance.new("UIStroke")
    s.Thickness = 3
    s.Color = color
    s.Transparency = 0.2
    s.Parent = inst
    return s
end

-- A round button with a label, a fill that rises from the bottom (energy, fuel, cooldown
-- progress) and a small sub label underneath the text.
local function makeButton(parent, text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(Screen.MIN_TAP, Screen.MIN_TAP)
    b.BackgroundColor3 = PANEL
    b.BackgroundTransparency = Theme.Transparency.Panel
    b.AutoButtonColor = true
    b.Text = ""
    b.Parent = parent
    round(b)
    local ring = stroke(b, color)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.AnchorPoint = Vector2.new(0.5, 1)
    fill.Position = UDim2.fromScale(0.5, 1)
    fill.Size = UDim2.fromScale(1, 0)
    fill.BackgroundColor3 = color
    fill.BackgroundTransparency = 0.6
    fill.BorderSizePixel = 0
    fill.Parent = b
    round(fill)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 0.4)
    label.Position = UDim2.fromScale(0, 0.22)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = TEXT
    label.ZIndex = 2
    label.Parent = b
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = label

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.fromScale(1, 0.22)
    sub.Position = UDim2.fromScale(0, 0.62)
    sub.BackgroundTransparency = 1
    sub.Text = ""
    sub.TextScaled = true
    sub.Font = Enum.Font.GothamBold
    sub.TextColor3 = MUTED
    sub.ZIndex = 2
    sub.Parent = b

    return { Button = b, Ring = ring, Fill = fill, Label = label, Sub = sub, Color = color }
end

-- Hold detection for a button: onChange(true) on press, onChange(false) on release, including
-- releases that end outside the button (the touch object reports its own state change).
local function holdable(button, onChange)
    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
    end
    button.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        onChange(true)
        input:GetPropertyChangedSignal("UserInputState"):Connect(function()
            if
                input.UserInputState == Enum.UserInputState.End
                or input.UserInputState == Enum.UserInputState.Cancel
            then
                onChange(false)
            end
        end)
    end)
    button.InputEnded:Connect(function(input)
        if isPress(input) then
            onChange(false)
        end
    end)
end

function TouchController:BuildGui()
    local gui = Screen.newScreenGui("TouchHud", Screen.Layers.Touch)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    -- Action column. It stacks *above* the bottom-right thumb cluster that Roblox's jump button
    -- and the Weapons Kit fire button already own, so no two tap targets ever overlap, and it
    -- uses a list layout instead of hand-computed offsets so a button appearing or disappearing
    -- (FLY, the abilities) re-flows the rest instead of leaving a hole.
    local column = Instance.new("Frame")
    column.Name = "Actions"
    column.AnchorPoint = Vector2.new(1, 1)
    column.BackgroundTransparency = 1
    column.AutomaticSize = Enum.AutomaticSize.XY
    column.Size = UDim2.fromOffset(0, 0)
    column.Parent = gui
    self.Column = column

    local col = Instance.new("UIListLayout")
    col.FillDirection = Enum.FillDirection.Vertical
    col.VerticalAlignment = Enum.VerticalAlignment.Bottom
    col.HorizontalAlignment = Enum.HorizontalAlignment.Right
    col.SortOrder = Enum.SortOrder.LayoutOrder
    col.Parent = column
    self.ColumnLayout = col

    -- FLY: hold while the jetpack is equipped
    self.Fly = makeButton(column, "FLY", FLY)
    self.Fly.Button.LayoutOrder = 10
    self.Fly.Sub.Text = "hold"
    self.Fly.Button.Visible = false
    holdable(self.Fly.Button, function(down)
        Knit.GetController("JetpackController").TouchHold = down
    end)

    -- Abilities: only while mutated, above the mutate slot they replace
    self.Abilities = {}
    for i, name in AlterEgos.ABILITY_ORDER do
        local b = makeButton(column, ABILITY_SHORT[name] or name, READY)
        b.Button.LayoutOrder = 20 + i
        b.Button.Visible = false
        b.Button.Activated:Connect(function()
            Knit.GetController("MutationController"):UseAbility(name)
        end)
        self.Abilities[name] = b
    end

    -- MUTATE: the most-used button, so it sits closest to the resting thumb
    self.Mutate = makeButton(column, "MUTATE", READY)
    self.Mutate.Button.LayoutOrder = 90
    self.Mutate.Button.Activated:Connect(function()
        Knit.GetController("MutationController"):Activate()
    end)

    local function pill(text, width)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(width, 44)
        b.BackgroundColor3 = PANEL
        b.BackgroundTransparency = Theme.Transparency.Panel
        b.Text = text
        b.TextSize = Theme.textSize(Theme.Type.Body)
        b.Font = Enum.Font.GothamBlack
        b.TextColor3 = TEXT
        b.Visible = false
        b.Parent = gui
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 12)
        c.Parent = b
        -- Pills keep their design pixel size and scale with the screen.
        Screen.autoScale(b)
        return b
    end

    -- SCORES: toggles the Tab scoreboard. Right edge, below the objective bar and clear of the
    -- aim zone; the safe-area inset keeps it off a notch in landscape.
    self.Scores = pill("SCORES", 104)
    self.Scores.AnchorPoint = Vector2.new(1, 0)

    -- SKIP: vote to skip the celebration. Bottom centre, above the skip label.
    self.Skip = pill("SKIP CELEBRATION", 210)
    self.Skip.AnchorPoint = Vector2.new(0.5, 1)
    self.Skip.Activated:Connect(function()
        Knit.GetController("CelebrationController"):VoteSkip()
    end)
    self.Scores.Activated:Connect(function()
        Knit.GetController("ScoreboardController"):Toggle()
    end)

    -- Every size and position below is recomputed on rotation, iPad Split View and window
    -- resizes, so the layout is correct on the first frame and after every change.
    Screen.onChange(function(state)
        local big = Screen.tapSize(88)
        local small = Screen.tapSize(72)
        local gap = math.max(10, math.floor(12 * state.Scale))
        self.ColumnLayout.Padding = UDim.new(0, gap)

        local function size(entry, px)
            entry.Button.Size = UDim2.fromOffset(px, px)
        end
        size(self.Mutate, big)
        size(self.Fly, small)
        for _, b in self.Abilities do
            size(b, small)
        end

        -- Bottom of the column = top of the right-hand thumb cluster, minus a gap.
        local thumbTop = state.ThumbRight and state.ThumbRight[2] or 1
        self.Column.Position = UDim2.new(1, -state.Insets.Right, thumbTop, -gap)

        self.Scores.Position = UDim2.new(1, -state.Insets.Right, 0, state.Insets.Top + math.floor(96 * state.Scale))
        self.Skip.Position = UDim2.new(0.5, 0, 1, -state.Insets.Bottom - math.floor(76 * state.Scale))
    end)
end

function TouchController:Update()
    local me = Players.LocalPlayer
    local inMatch = me:GetAttribute("InMatch") == true
    local mutationCtl = Knit.GetController("MutationController")
    local nowServer = workspace:GetServerTimeNow()

    self.Scores.Visible = inMatch and Knit.GetController("ScoreboardController").Rows ~= nil
    local celebration = Knit.GetController("CelebrationController")
    self.Skip.Visible = celebration.SkipLabel ~= nil and celebration.SkipLabel.Visible

    local jet = Knit.GetController("JetpackController")
    self.Fly.Button.Visible = inMatch and jet.Active
    if jet.Active and jet.MaxFuel > 0 then
        local frac = jet.Fuel / jet.MaxFuel
        self.Fly.Fill.Size = UDim2.fromScale(1, frac)
        self.Fly.Sub.Text = ("HOLD %d%%"):format(100 * frac)
        self.Fly.Ring.Transparency = jet.Fuel > 0 and 0.2 or 0.8
    end

    if not inMatch then
        self.Mutate.Button.Visible = false
        for _, b in self.Abilities do
            b.Button.Visible = false
        end
        return
    end

    local ego = AlterEgos.get(me:GetAttribute("AlterEgo") or AlterEgos.DEFAULT)
    local mutated = me:GetAttribute("Mutated") ~= nil
    local energy = me:GetAttribute("MutationEnergy") or 0
    local ready = energy >= AlterEgos.Energy.Cap

    self.Mutate.Button.Visible = not mutated
    if not mutated then
        self.Mutate.Fill.Size = UDim2.fromScale(1, energy / AlterEgos.Energy.Cap)
        self.Mutate.Sub.Text = ready and "READY" or ("%d%%"):format(100 * energy / AlterEgos.Energy.Cap)
        self.Mutate.Label.TextColor3 = ready and TEXT or MUTED
        local pulse = ready and (0.5 + 0.5 * math.sin(os.clock() * 6)) or 0
        self.Mutate.Ring.Transparency = ready and (0.6 - 0.6 * pulse) or 0.7
        self.Mutate.Fill.BackgroundTransparency = ready and (0.3 + 0.3 * pulse) or 0.6
    end

    for name, b in self.Abilities do
        b.Button.Visible = mutated
        if mutated then
            local def = ego.Abilities[name]
            local cdEnd = mutationCtl.CooldownEnds[name] or 0
            local cdLeft = math.max(0, cdEnd - nowServer)
            local progress = def.Cooldown > 0 and 1 - math.min(1, cdLeft / def.Cooldown) or 1
            b.Fill.Size = UDim2.fromScale(1, progress)
            b.Sub.Text = cdLeft > 0 and ("%.1fs"):format(cdLeft) or "READY"
            b.Label.TextColor3 = cdLeft > 0 and MUTED or TEXT
            b.Ring.Transparency = cdLeft > 0 and 0.7 or 0.1
        end
    end
end

function TouchController:KnitStart()
    self:BuildGui()
    local function refreshEnabled()
        self.Gui.Enabled = TouchController.IsTouch()
    end
    -- A Bluetooth keyboard connecting, a rotation or an iPad Split View resize can all flip the
    -- device class, and Screen fires on every one of them.
    Screen.onChange(refreshEnabled)
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    if tuning then
        tuning:GetAttributeChangedSignal("Debug_ForceTouchUi"):Connect(refreshEnabled)
    end

    RunService.RenderStepped:Connect(function()
        if self.Gui.Enabled then
            self:Update()
        end
    end)
end

return TouchController
