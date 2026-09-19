-- Mutation HUD + input: meter with percentage, MUTATION READY, mutant timer, ability cooldowns,
-- Q to activate, E/F/C abilities. Applies server-sent knockback and charge movement to the local
-- character (client-owned physics). Never decides energy, damage, or cooldowns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local MutationController = Knit.CreateController({ Name = "MutationController" })

local PANEL = Theme.Color.Panel
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local READY = Theme.Color.Energy

local KEYS = { Q = Enum.KeyCode.Q, E = Enum.KeyCode.E, F = Enum.KeyCode.F, C = Enum.KeyCode.C }

function MutationController:BuildGui()
    local gui = Screen.newScreenGui("MutationHud", Screen.Layers.Meter)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 1, -110)
    frame.Size = UDim2.fromOffset(320, 64)
    -- Designed at 320x64 for a desktop window; the UIScale keeps that proportion on a phone.
    Screen.autoScale(frame)
    frame.BackgroundColor3 = PANEL
    frame.BackgroundTransparency = Theme.Transparency.Panel
    frame.Parent = gui
    self.Frame = frame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Position = UDim2.new(0, 10, 0, 4)
    title.Size = UDim2.new(1, -20, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = "TITAN"
    title.TextSize = Theme.textSize(Theme.Type.Label)
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = READY
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    self.Title = title

    local back = Instance.new("Frame")
    back.Position = UDim2.new(0, 10, 0, 26)
    back.Size = UDim2.new(1, -20, 0, 12)
    back.BackgroundColor3 = Theme.Color.Track
    back.BorderSizePixel = 0
    back.Parent = frame
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 6)
    bc.Parent = back
    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromScale(0, 1)
    bar.BackgroundColor3 = READY
    bar.BorderSizePixel = 0
    bar.Parent = back
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 6)
    fc.Parent = bar
    self.Bar = bar

    local pct = Instance.new("TextLabel")
    pct.AnchorPoint = Vector2.new(1, 0)
    pct.Position = UDim2.new(1, -10, 0, 4)
    pct.Size = UDim2.new(0.6, 0, 0, 18)
    pct.BackgroundTransparency = 1
    pct.Text = "0%"
    pct.TextSize = Theme.textSize(Theme.Type.Label)
    pct.Font = Enum.Font.GothamBold
    pct.TextColor3 = TEXT
    pct.TextXAlignment = Enum.TextXAlignment.Right
    pct.Parent = frame
    self.Pct = pct

    -- ability row
    local row = Instance.new("Frame")
    row.Position = UDim2.new(0, 10, 0, 42)
    row.Size = UDim2.new(1, -20, 0, 18)
    row.BackgroundTransparency = 1
    row.Parent = frame
    self.Row = row
    self.Abilities = {}
    for i, name in AlterEgos.ABILITY_ORDER do
        local l = Instance.new("TextLabel")
        l.Position = UDim2.fromScale((i - 1) / 3, 0)
        l.Size = UDim2.fromScale(1 / 3, 1)
        l.BackgroundTransparency = 1
        l.TextSize = Theme.textSize(Theme.Type.Label)
        l.Font = Enum.Font.GothamBold
        l.TextColor3 = MUTED
        l.Parent = row
        self.Abilities[name] = l
    end
    self.CooldownEnds = {}
end

function MutationController:Touch()
    return Knit.GetController("TouchController").IsTouch()
end

function MutationController:Update()
    local me = Players.LocalPlayer
    local inMatch = me:GetAttribute("InMatch") == true
    self.Gui.Enabled = inMatch
    if not inMatch then
        return
    end
    -- On touch the ability row is replaced by the on-screen buttons, so the panel loses a line.
    -- It also moves out of the bottom centre: on a phone that strip belongs to the backpack
    -- hotbar and the jump button, and anything sitting there lands on top of the player's own
    -- character. Top-left, under the Roblox pills, is the one strip nothing else claims.
    local touch = self:Touch()
    local state = Screen.get()
    self.Row.Visible = not touch
    self.Frame.Size = touch and UDim2.fromOffset(320, 44) or UDim2.fromOffset(320, 64)
    if touch then
        self.Frame.AnchorPoint = Vector2.new(0, 0)
        self.Frame.Position = UDim2.new(0, state.Insets.Left, 0, state.Insets.Top + 52)
    else
        self.Frame.AnchorPoint = Vector2.new(0.5, 1)
        self.Frame.Position = UDim2.new(0.5, 0, 1, -110 - state.Insets.Bottom)
    end
    local ego = AlterEgos.get(me:GetAttribute("AlterEgo") or AlterEgos.DEFAULT)
    local energy = me:GetAttribute("MutationEnergy") or 0
    local mutated = me:GetAttribute("Mutated")
    local endsAt = me:GetAttribute("MutationEndsAt")
    if mutated and endsAt then
        local left = math.max(0, endsAt - workspace:GetServerTimeNow())
        self.Title.Text = ("%s  %.1fs"):format(mutated:upper(), left)
        self.Bar.Size = UDim2.fromScale(left / AlterEgos.Mutation.DurationSeconds, 1)
        self.Pct.Text = ""
        for name, l in self.Abilities do
            local def = ego.Abilities[name]
            local cdEnd = self.CooldownEnds[name] or 0
            local cdLeft = math.max(0, cdEnd - workspace:GetServerTimeNow())
            l.Text = cdLeft > 0 and ("%s %s %.1f"):format(def.Key, name, cdLeft)
                or ("%s %s READY"):format(def.Key, name)
            l.TextColor3 = cdLeft > 0 and MUTED or TEXT
        end
    else
        local hint = self:Touch() and "tap MUTATE" or ("press " .. AlterEgos.Mutation.ActivateKey)
        self.Title.Text = energy >= AlterEgos.Energy.Cap and ("MUTATION READY  " .. hint) or ego.Name:upper()
        self.Bar.Size = UDim2.fromScale(energy / AlterEgos.Energy.Cap, 1)
        self.Pct.Text = ("%d%%"):format(energy)
        local pulse = energy >= AlterEgos.Energy.Cap and (0.5 + 0.5 * math.sin(os.clock() * 6)) or 1
        self.Bar.BackgroundTransparency = 1 - pulse
        for name, l in self.Abilities do
            l.Text = ("%s %s"):format(ego.Abilities[name].Key, name)
            l.TextColor3 = MUTED
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
            Knit.GetController("ConvergenceController"):ShowBanner("Cannot mutate: " .. why, MUTED)
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
        conv:ShowBanner(text .. (who == Players.LocalPlayer.Name and "" or ("  (" .. who .. ")")), READY)
    end)
    mutation.Ready:Connect(function()
        conv:ShowBanner(self:Touch() and "MUTATION READY  tap MUTATE" or "MUTATION READY  press Q", READY)
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
