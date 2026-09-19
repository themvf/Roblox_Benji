-- Touch HUD for phones and tablets. Draws big on-screen buttons for everything the desktop
-- build binds to keys: Mutate (Q), Ground Slam / Brace / Charge (E/F/C), hold-to-fly for the
-- jetpack, a scoreboard toggle (Tab) and the celebration skip vote (V). Guns already get a fire
-- button and drag-to-aim from the Weapons Kit, and movement/jump come from Roblox's own touch
-- controls, so those are not duplicated here. Only rendering and input: every action goes
-- through the same controller methods the keyboard uses, so the server sees identical requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)

local TouchController = Knit.CreateController({ Name = "TouchController" })

local PANEL = Color3.fromRGB(20, 22, 28)
local TEXT = Color3.fromRGB(245, 245, 250)
local MUTED = Color3.fromRGB(160, 165, 180)
local READY = Color3.fromRGB(255, 120, 40)
local FLY = Color3.fromRGB(90, 200, 255)

local ABILITY_SHORT = { GroundSlam = "SLAM", Brace = "BRACE", Charge = "CHARGE" }

-- Touch device = has a touchscreen and no keyboard (a laptop with a touchscreen keeps the
-- keyboard layout). Tuning.Debug_ForceTouchUi = true shows the touch HUD anywhere, so it can be
-- checked in Studio without the device emulator.
function TouchController.IsTouch()
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    if tuning and tuning:GetAttribute("Debug_ForceTouchUi") == true then
        return true
    end
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
local function makeButton(parent, size, text, color)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 1)
    b.Size = UDim2.fromOffset(size, size)
    b.BackgroundColor3 = PANEL
    b.BackgroundTransparency = 0.25
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
    local gui = Instance.new("ScreenGui")
    gui.Name = "TouchHud"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 5
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    -- Phones get ~64 px buttons, tablets ~84 px. The column sits to the left of Roblox's own
    -- jump button, which lives in the bottom-right corner.
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(812, 375)
    local tablet = viewport.Y >= 600
    local big = tablet and 96 or 76
    local small = tablet and 84 or 64
    local gap = 12
    local rightInset = tablet and 150 or 110

    -- MUTATE: one big button in place of the ability cluster until the player is mutated
    self.Mutate = makeButton(gui, big, "MUTATE", READY)
    self.Mutate.Button.Position = UDim2.new(1, -rightInset, 1, -24)
    self.Mutate.Button.Activated:Connect(function()
        Knit.GetController("MutationController"):Activate()
    end)

    -- Abilities: stacked column, only while mutated
    self.Abilities = {}
    for i, name in AlterEgos.ABILITY_ORDER do
        local b = makeButton(gui, small, ABILITY_SHORT[name] or name, READY)
        b.Button.Position = UDim2.new(1, -rightInset, 1, -24 - (i - 1) * (small + gap))
        b.Button.Visible = false
        b.Button.Activated:Connect(function()
            Knit.GetController("MutationController"):UseAbility(name)
        end)
        self.Abilities[name] = b
    end

    -- FLY: hold while the jetpack is equipped; above the jump button
    self.Fly = makeButton(gui, small, "FLY", FLY)
    self.Fly.Button.Position = UDim2.new(1, -24, 1, -24 - small - 40)
    self.Fly.Sub.Text = "hold"
    self.Fly.Button.Visible = false
    holdable(self.Fly.Button, function(down)
        Knit.GetController("JetpackController").TouchHold = down
    end)

    local function pill(text, width)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(width, 44)
        b.BackgroundColor3 = PANEL
        b.BackgroundTransparency = 0.25
        b.Text = text
        b.TextSize = 16
        b.Font = Enum.Font.GothamBlack
        b.TextColor3 = TEXT
        b.Visible = false
        b.Parent = gui
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 12)
        c.Parent = b
        return b
    end

    -- SCORES: toggles the Tab scoreboard, top-right under the match panel
    self.Scores = pill("SCORES", 100)
    self.Scores.AnchorPoint = Vector2.new(1, 0)
    self.Scores.Position = UDim2.new(1, -16, 0, 100)
    self.Scores.Activated:Connect(function()
        Knit.GetController("ScoreboardController"):Toggle()
    end)

    -- SKIP: vote to skip the celebration
    self.Skip = pill("SKIP CELEBRATION", 200)
    self.Skip.AnchorPoint = Vector2.new(0.5, 1)
    self.Skip.Position = UDim2.new(0.5, 0, 1, -84) -- above the "vote skip" label
    self.Skip.Activated:Connect(function()
        Knit.GetController("CelebrationController"):VoteSkip()
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
        self.Fly.Sub.Text = ("%d%%"):format(100 * frac)
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
        self.Mutate.Sub.Text = ready and "TAP!" or ("%d%%"):format(energy)
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
            b.Sub.Text = cdLeft > 0 and ("%.1f"):format(cdLeft) or "READY"
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
    refreshEnabled()
    -- a Bluetooth keyboard connecting or disconnecting mid session flips the layout
    UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refreshEnabled)
    UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refreshEnabled)
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
