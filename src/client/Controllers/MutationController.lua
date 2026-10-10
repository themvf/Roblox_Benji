-- Mutation HUD + input. Q to activate, E/F/C abilities. Applies server-sent knockback and
-- charge movement to the local character (client-owned physics). Never decides energy,
-- damage, or cooldowns.
--
-- The HUD is two icon groups docked either side of the weapon slots, Rivals-style, instead of
-- a text panel: on the left a round power icon that fills with energy and pulses when ready,
-- with a small Q keycap; while mutated it drains with the time left, and the three ability
-- icons appear on the right with a cooldown shade and seconds. The abilities are not shown
-- before the mutation exists -- greyed-out "E GroundSlam" next to a half-full meter read as
-- "you have these now". Touch players get the same state on TouchController's buttons, so
-- this whole gui is off there.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Icons = require(script.Parent.Parent.UI.Icons)

local MutationController = Knit.CreateController({ Name = "MutationController" })

local PANEL = Theme.Color.Panel
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local READY = Theme.Color.Energy

local KEYS = { Q = Enum.KeyCode.Q, E = Enum.KeyCode.E, F = Enum.KeyCode.F, C = Enum.KeyCode.C }

local ORB = 60 -- the weapon slots are 60 tall; the dock lines up with them
local TILE = 52
local DOCK_GAP = 12

-- Titan charge reads as a STATE, not a percentage. The icon changes character at thresholds
-- rather than only filling:
--   0-49   dormant  -- muted, easy to ignore
--   50-74  stirring -- warms up
--   75-99  surging  -- slow pulse
--   100    ready    -- bright, fast pulse
local STAGES = {
    { at = 100, name = "ready", color = Theme.Color.Accent, pulse = 7 },
    { at = 75, name = "surging", color = Theme.Color.Energy, pulse = 3 },
    { at = 50, name = "stirring", color = Theme.Color.Warn, pulse = 0 },
    { at = 0, name = "dormant", color = Theme.Color.TextMuted, pulse = 0 },
}

local function stageFor(pct: number)
    for _, st in STAGES do
        if pct >= st.at then
            return st
        end
    end
    return STAGES[#STAGES]
end

local function round(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 10)
    c.Parent = inst
end

-- A small key badge in a tile's top-right corner. Keyboard only: this gui is off on touch.
local function keycap(parent, key)
    local cap = Instance.new("TextLabel")
    cap.AnchorPoint = Vector2.new(1, 0)
    cap.Position = UDim2.new(1, -3, 0, 3)
    cap.Size = UDim2.fromOffset(18, 18)
    cap.BackgroundColor3 = Theme.Color.PanelHigh
    cap.Text = key
    cap.TextSize = Theme.textSize(Theme.Type.Label)
    cap.Font = Enum.Font.GothamBlack
    cap.TextColor3 = TEXT
    cap.ZIndex = 4
    cap.Parent = parent
    round(cap, UDim.new(0, 4))
    return cap
end

-- A rounded tile with an icon and a fill rising from the bottom. A CanvasGroup, so the fill is
-- clipped to the rounded corners instead of poking out square.
local function tile(parent, iconName, size, radius)
    local t = Instance.new("CanvasGroup")
    t.Size = UDim2.fromOffset(size, size)
    t.BackgroundColor3 = PANEL
    t.BackgroundTransparency = Theme.Transparency.Panel
    t.Parent = parent
    round(t, radius)
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.AnchorPoint = Vector2.new(0.5, 1)
    fill.Position = UDim2.fromScale(0.5, 1)
    fill.Size = UDim2.fromScale(1, 0)
    fill.BackgroundColor3 = READY
    fill.BackgroundTransparency = 0.55
    fill.BorderSizePixel = 0
    fill.Parent = t
    local icon = Icons.make(t, iconName, UDim2.fromScale(0.58, 0.58))
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.ZIndex = 2
    local ring = Instance.new("UIStroke")
    ring.Thickness = 2
    ring.Color = READY
    ring.Transparency = 1
    ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ring.Parent = t
    return { Frame = t, Fill = fill, Icon = icon, Ring = ring }
end

function MutationController:BuildGui()
    local gui = Screen.newScreenGui("MutationHud", Screen.Layers.Meter)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    -- left of the weapon slots: the power icon
    local orb = tile(gui, "Mutate", ORB, UDim.new(0.5, 0))
    orb.Frame.AnchorPoint = Vector2.new(1, 1)
    Screen.autoScale(orb.Frame)
    keycap(orb.Frame, AlterEgos.Mutation.ActivateKey)
    local timer = Instance.new("TextLabel")
    timer.AnchorPoint = Vector2.new(0.5, 1)
    timer.Position = UDim2.new(0.5, 0, 1, -2)
    timer.Size = UDim2.new(1, 0, 0, 16)
    timer.BackgroundTransparency = 1
    timer.Text = ""
    timer.TextSize = Theme.textSize(Theme.Type.Label)
    timer.Font = Enum.Font.GothamBlack
    timer.TextColor3 = TEXT
    timer.ZIndex = 3
    timer.Parent = orb.Frame
    orb.Timer = timer
    self.Orb = orb

    -- right of the weapon slots, only while mutated: the abilities
    local row = Instance.new("Frame")
    row.AnchorPoint = Vector2.new(0, 1)
    row.Size = UDim2.fromOffset(3 * TILE + 2 * 8, TILE)
    row.BackgroundTransparency = 1
    row.Visible = false
    row.Parent = gui
    Screen.autoScale(row)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = row
    self.Row = row
    self.Abilities = {}
    local ego = AlterEgos.get(AlterEgos.DEFAULT)
    for i, name in AlterEgos.ABILITY_ORDER do
        local t = tile(row, Icons.ABILITY[name] or "Info", TILE)
        t.Frame.LayoutOrder = i
        -- cooldown: a shade that drops away from the top as the ability comes back
        t.Fill.AnchorPoint = Vector2.new(0.5, 0)
        t.Fill.Position = UDim2.fromScale(0.5, 0)
        t.Fill.BackgroundColor3 = PANEL
        t.Fill.BackgroundTransparency = 0.25
        t.Fill.ZIndex = 3
        keycap(t.Frame, ego.Abilities[name].Key)
        local secs = Instance.new("TextLabel")
        secs.Size = UDim2.fromScale(1, 1)
        secs.BackgroundTransparency = 1
        secs.Text = ""
        secs.TextSize = Theme.textSize(Theme.Type.Title)
        secs.Font = Enum.Font.GothamBlack
        secs.TextColor3 = TEXT
        secs.ZIndex = 5
        secs.Parent = t.Frame
        t.Seconds = secs
        self.Abilities[name] = t
    end
    self.CooldownEnds = {}
end

function MutationController:Touch()
    return Knit.GetController("TouchController").IsTouch()
end

function MutationController:Update()
    local me = Players.LocalPlayer
    local inMatch = me:GetAttribute("InMatch") == true
    self.Gui.Enabled = inMatch and not self:Touch()
    if not self.Gui.Enabled then
        return
    end

    -- dock either side of the weapon slots, whatever width the row has right now
    local state = Screen.get()
    local bar = Knit.GetController("WeaponBarController")
    local half = bar.Row and bar.Row.AbsoluteSize.X / 2 or 0
    local bottom = -state.Insets.Bottom - bar.BOTTOM_GAP
    self.Orb.Frame.Position = UDim2.new(0.5, -half - DOCK_GAP, 1, bottom)
    self.Row.Position = UDim2.new(0.5, half + DOCK_GAP, 1, bottom - (bar.SLOT_HEIGHT - TILE) / 2)

    local ego = AlterEgos.get(me:GetAttribute("AlterEgo") or AlterEgos.DEFAULT)
    local energy = me:GetAttribute("MutationEnergy") or 0
    local mutated = me:GetAttribute("Mutated")
    local endsAt = me:GetAttribute("MutationEndsAt")
    local now = workspace:GetServerTimeNow()
    local orb = self.Orb

    self.Row.Visible = mutated ~= nil
    if mutated and endsAt then
        local left = math.max(0, endsAt - now)
        orb.Fill.Size = UDim2.fromScale(1, left / AlterEgos.Mutation.DurationSeconds)
        orb.Fill.BackgroundColor3 = READY
        orb.Timer.Text = ("%.0f"):format(left)
        Icons.tint(orb.Icon, TEXT)
        orb.Ring.Color = READY
        orb.Ring.Transparency = 0
        for name, t in self.Abilities do
            local def = ego.Abilities[name]
            local cdLeft = math.max(0, (self.CooldownEnds[name] or 0) - now)
            local shade = def.Cooldown > 0 and math.min(1, cdLeft / def.Cooldown) or 0
            t.Fill.Size = UDim2.fromScale(1, shade)
            t.Seconds.Text = cdLeft > 0 and ("%d"):format(math.ceil(cdLeft)) or ""
            Icons.tint(t.Icon, cdLeft > 0 and MUTED or TEXT)
            t.Ring.Transparency = cdLeft > 0 and 1 or 0.2
        end
    else
        local pct = (energy / AlterEgos.Energy.Cap) * 100
        local stage = stageFor(pct)
        orb.Fill.Size = UDim2.fromScale(1, math.clamp(energy / AlterEgos.Energy.Cap, 0, 1))
        orb.Fill.BackgroundColor3 = stage.color
        orb.Timer.Text = ""
        Icons.tint(orb.Icon, stage.name == "dormant" and MUTED or TEXT)
        orb.Ring.Color = stage.color
        -- pulse rate is the anticipation: nothing until 75, slow while surging, fast when ready
        if stage.pulse > 0 then
            local wave = 0.5 + 0.5 * math.sin(os.clock() * stage.pulse)
            orb.Ring.Transparency = 0.6 * (1 - wave)
        else
            orb.Ring.Transparency = 1
        end
    end
end

-- Shared by keyboard and the touch HUD (TouchController) so both send identical requests.
function MutationController:Activate()
    if not Players.LocalPlayer:GetAttribute("InMatch") then
        return
    end
    Knit.GetService("MutationService"):Activate():andThen(function(ok, why)
        if not ok and why and why ~= "not ready" then
            Knit.GetController("ConvergenceController"):ShowBanner("Cannot mutate: " .. why, MUTED, "Info")
        end
    end)
end

function MutationController:UseAbility(name)
    local me = Players.LocalPlayer
    if me:GetAttribute("InMatch") and me:GetAttribute("Mutated") then
        Knit.GetService("AbilityService"):Use(name)
    end
end

function MutationController:KnitStart()
    self:BuildGui()
    local mutation = Knit.GetService("MutationService")
    local ability = Knit.GetService("AbilityService")
    local conv = Knit.GetController("ConvergenceController")

    mutation.Announce:Connect(function(text, who)
        if text:find("reverted") then
            return
        end
        conv:ShowBanner(text .. (who == Players.LocalPlayer.Name and "" or ("  (" .. who .. ")")), READY, "Mutate")
    end)
    mutation.Ready:Connect(function()
        conv:ShowBanner("MUTATION READY", READY, "Mutate")
    end)
    ability.Cooldowns:Connect(function(map)
        self.CooldownEnds = map
    end)
    ability.Knockback:Connect(function(velocity)
        local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if root and hum then
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
            root.AssemblyLinearVelocity = velocity
        end
    end)
    ability.Charge:Connect(function(speed, duration, steer)
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not hum then
            return
        end
        local dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
        local t0 = os.clock()
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if os.clock() - t0 > duration or not root.Parent then
                conn:Disconnect()
                return
            end
            -- limited steering toward the camera's current look
            local cam = workspace.CurrentCamera.CFrame.LookVector
            local want = Vector3.new(cam.X, 0, cam.Z)
            if want.Magnitude > 0.1 then
                want = want.Unit
                local maxTurn = math.rad(steer) * dt
                local angle = math.acos(math.clamp(dir:Dot(want), -1, 1))
                if angle > 0.001 then
                    local turn = math.min(angle, maxTurn)
                    local axis = dir:Cross(want).Y >= 0 and 1 or -1
                    dir = (CFrame.Angles(0, turn * axis, 0) * dir)
                    dir = Vector3.new(dir.X, 0, dir.Z).Unit
                end
            end
            root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
            root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, root.AssemblyLinearVelocity.Y, dir.Z * speed)
        end)
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end
        local me = Players.LocalPlayer
        if not me:GetAttribute("InMatch") then
            return
        end
        if input.KeyCode == KEYS[AlterEgos.Mutation.ActivateKey] then
            self:Activate()
            return
        end
        if me:GetAttribute("Mutated") then
            local ego = AlterEgos.get(me:GetAttribute("AlterEgo") or AlterEgos.DEFAULT)
            for name, def in ego.Abilities do
                if input.KeyCode == KEYS[def.Key] then
                    self:UseAbility(name)
                end
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        self:Update()
    end)
end

return MutationController
