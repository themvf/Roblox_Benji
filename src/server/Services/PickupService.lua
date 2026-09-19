-- Pickups and launch pads (Carrier spec S11-S14, S16, S22).
--   weapon   temporary special weapon (tool) until death or Duration; long respawn; strong, contestable
--   speed    +25% WalkSpeed for 7 s with a trail; 12 s re-pickup cooldown per player; never stacks
--   jetpack  temporary jetpack tool with 3.5 s of thrust and no recharge; 1-2 on the map; 50 s respawn
--   launch pads   directional ballistic arc to a landing point; loud, visible, predictable
-- Layout data: layout.Pickups = { {kind, pos, weapon?, respawn?} }, layout.LaunchPads = { {pos, target, size?} }
-- Telemetry per match in PickupService.Stats (printed by ConvergenceService at match end).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local PickupService = Knit.CreateService({
    Name = "PickupService",
    Client = {
        Notice = Knit.CreateSignal(), -- (text) small HUD toast
        Launch = Knit.CreateSignal(), -- (velocity, flightSeconds) client applies it (character is client-owned)
    },
})

local COLORS = {
    weapon = Color3.fromRGB(255, 120, 60),
    speed = Color3.fromRGB(80, 255, 160),
    jetpack = Color3.fromRGB(120, 200, 255),
    pad = Color3.fromRGB(255, 220, 60),
}
local DEFAULTS = {
    weapon = { Respawn = 60, Duration = 45 },
    speed = { Respawn = 20, Duration = 7, Multiplier = 1.25, Cooldown = 12 },
    jetpack = { Respawn = 50, Fuel = 3.5 },
}
local GRAVITY = 196.2

PickupService.Stats = nil

local function resetStats()
    PickupService.Stats = {
        LaunchUses = 0,
        LaunchDeathsInFlight = 0,
        SpeedUses = 0,
        JetpackUses = 0,
        WeaponUses = 0,
        DeathsNearPickups = 0,
    }
end
resetStats()

-- ===== visuals (S16 consistent language) =====
local function basePad(folder, name, pos, color)
    local pad = Instance.new("Part")
    pad.Name = name
    pad.Shape = Enum.PartType.Cylinder
    pad.Anchored = true
    pad.CanCollide = false
    pad.CanQuery = false
    pad.Material = Enum.Material.Neon
    pad.Color = color
    pad.Transparency = 0.3
    pad.Size = Vector3.new(0.3, 5, 5)
    pad.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pad.Parent = folder
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = 14
    light.Brightness = 1.5
    light.Parent = pad
    return pad
end

local function icon(parent, text, color)
    -- Stud-sized so a far pickup reads as far away instead of shouting over the touch buttons
    -- (see the zone signs in ConvergenceService for the same reasoning).
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromScale(4, 1.4)
    bb.StudsOffset = Vector3.new(0, 4.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 90
    bb.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextScaled = true
    l.Font = Enum.Font.GothamBlack
    l.TextColor3 = color
    Palette.worldText(l)
    l.Parent = bb
    return l
end

local function weaponModel(name)
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local tool = tools and tools:FindFirstChild(name)
    local src = tool and tool:FindFirstChildOfClass("Model")
    if not src then
        return nil
    end
    local m = src:Clone()
    for _, d in m:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
            d:Destroy()
        end
    end
    return m
end

local function speedModel()
    local m = Instance.new("Model")
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.Material = Enum.Material.Neon
    ring.Color = COLORS.speed
    ring.Size = Vector3.new(0.4, 3, 3)
    ring.Parent = m
    local arrow = Instance.new("WedgePart")
    arrow.Anchored = true
    arrow.CanCollide = false
    arrow.CanQuery = false
    arrow.Material = Enum.Material.Neon
    arrow.Color = Color3.new(1, 1, 1)
    arrow.Size = Vector3.new(0.6, 1.6, 1.6)
    arrow.Parent = m
    m.PrimaryPart = ring
    arrow.CFrame = ring.CFrame * CFrame.new(0, 0, 0)
    return m
end

local function jetpackModel()
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local tool = tools and tools:FindFirstChild("Jetpack")
    local src = tool and tool:FindFirstChild("Pack")
    if not src then
        return nil
    end
    local m = src:Clone()
    for _, d in m:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
        elseif d:IsA("ParticleEmitter") then
            d.Enabled = true
            d.Rate = 12
        end
    end
    return m
end

-- ===== pickup lifecycle =====
local function makePickup(folder, spec, index)
    local kind = spec.kind
    local color = COLORS[kind] or Color3.new(1, 1, 1)
    local pos = Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3])
    local pad = basePad(folder, ("Pickup_%s_%d"):format(kind, index), pos, color)
    local label = icon(pad, kind == "weapon" and (spec.weapon or "WEAPON"):upper() or kind:upper(), color)
    local model
    if kind == "weapon" then
        model = weaponModel(spec.weapon)
    elseif kind == "speed" then
        model = speedModel()
    elseif kind == "jetpack" then
        model = jetpackModel()
    end
    if model then
        model.Name = "PickupModel"
        if kind == "weapon" then
            model:ScaleTo(1.6)
        end
        model:PivotTo(CFrame.new(pos + Vector3.new(0, 2.5, 0)))
        model.Parent = pad
        local hl = Instance.new("Highlight")
        hl.FillTransparency = 0.7
        hl.FillColor = color
        hl.OutlineColor = color
        hl.Parent = model
    end
    local defaults = DEFAULTS[kind] or {}
    local pickup = {
        Kind = kind,
        Spec = spec,
        Pad = pad,
        Model = model,
        Label = label,
        Pos = pos,
        Ready = true,
        Respawn = spec.respawn or defaults.Respawn or 30,
    }
    return pickup
end

local function setReady(pickup, ready, secondsLeft)
    pickup.Ready = ready
    pickup.Pad.Transparency = ready and 0.3 or 0.85
    if pickup.Model then
        for _, d in pickup.Model:GetDescendants() do
            if d:IsA("BasePart") then
                d.Transparency = ready and 0 or 0.9
            end
        end
    end
    if not ready and secondsLeft then
        pickup.Label.Text = ("%ds"):format(math.ceil(secondsLeft))
    elseif ready then
        pickup.Label.Text = pickup.Kind == "weapon" and (pickup.Spec.weapon or "WEAPON"):upper() or pickup.Kind:upper()
    end
end

local function playSound(parent, ref, volume)
    local id = Uploads.resolve(ref)
    if not id then
        return
    end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume or 0.8
    s.RollOffMaxDistance = 90
    s.Parent = parent
    s:Play()
    Debris:AddItem(s, 4)
end

-- ===== effects on players =====
function PickupService:GiveWeapon(player, weaponName, duration)
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChildOfClass("Backpack")
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local template = tools and tools:FindFirstChild(weaponName)
    if not hum or not backpack or not template then
        return
    end
    -- one special at a time
    for _, container in { backpack, character } do
        for _, t in container:GetChildren() do
            if t:IsA("Tool") and t:GetAttribute("Pickup") then
                t:Destroy()
            end
        end
    end
    local tool = template:Clone()
    tool:SetAttribute("Pickup", true)
    tool.Name = weaponName
    tool.Parent = backpack
    Knit.GetService("SkinService"):Apply(tool, player)
    hum:EquipTool(tool)
    task.delay(duration, function()
        if tool.Parent then
            tool:Destroy()
            self.Client.Notice:Fire(player, weaponName .. " expired")
        end
    end)
end

function PickupService:GiveSpeed(player, mult, duration)
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    if character:GetAttribute("SpeedBoost") then
        return -- no stacking
    end
    local base = hum.WalkSpeed
    character:SetAttribute("SpeedBoost", true)
    hum.WalkSpeed = base * mult
    -- trail so the boost is visible to others
    local root = character:FindFirstChild("HumanoidRootPart")
    local trail
    if root then
        local a0 = Instance.new("Attachment")
        a0.Position = Vector3.new(0, 1, 0)
        a0.Parent = root
        local a1 = Instance.new("Attachment")
        a1.Position = Vector3.new(0, -1, 0)
        a1.Parent = root
        trail = Instance.new("Trail")
        trail.Attachment0 = a0
        trail.Attachment1 = a1
        trail.Color = ColorSequence.new(COLORS.speed)
        trail.Lifetime = 0.35
        trail.LightEmission = 1
        trail.Parent = root
    end
    task.delay(duration, function()
        if hum.Parent then
            hum.WalkSpeed = base
        end
        if character.Parent then
            character:SetAttribute("SpeedBoost", nil)
        end
        if trail then
            trail:Destroy()
        end
    end)
end

function PickupService:GiveJetpack(player, fuelSeconds)
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChildOfClass("Backpack")
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local template = tools and tools:FindFirstChild("Jetpack")
    if not hum or not backpack or not template then
        return
    end
    for _, container in { backpack, character } do
        for _, t in container:GetChildren() do
            if t:IsA("Tool") and t.Name == "Jetpack" then
                t:Destroy()
            end
        end
    end
    local tool = template:Clone()
    tool:SetAttribute("Pickup", true)
    tool:SetAttribute("Temporary", true)
    tool:SetAttribute("FuelSeconds", fuelSeconds) -- JetpackController: no recharge, expires when spent
    tool.Parent = backpack
    hum:EquipTool(tool)
end

-- ===== launch pads (S14) =====
-- Ballistic arc: given a vertical launch speed, the flight time and horizontal speed that lands at `to`.
local function launchVelocity(from, to, vy)
    local dy = to.Y - from.Y
    -- solve vy*t - g/2*t^2 = dy for the later root
    local disc = vy * vy - 2 * GRAVITY * dy
    if disc < 0 then
        vy = math.sqrt(2 * GRAVITY * dy) + 12
        disc = vy * vy - 2 * GRAVITY * dy
    end
    local t = (vy + math.sqrt(disc)) / GRAVITY
    local horiz = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
    return horiz / t + Vector3.new(0, vy, 0), t
end

local function makeLaunchPad(self, folder, spec, index)
    local pos = Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3])
    local target = Vector3.new(spec.target[1], spec.target[2], spec.target[3])
    local size = spec.size or 8
    local debug = Knit.GetService("SafetyService"):TestAids()

    local pad = Instance.new("Part")
    pad.Name = "LaunchPad" .. index
    pad.Anchored = true
    pad.CanCollide = true
    pad.Material = Enum.Material.Neon
    pad.Color = COLORS.pad
    pad.Size = Vector3.new(size, 0.6, size)
    pad.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0))
    pad.Parent = folder
    local dir = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z).Unit
    for i = 1, 3 do
        local chev = Instance.new("WedgePart")
        chev.Anchored = true
        chev.CanCollide = false
        chev.CanQuery = false
        chev.Material = Enum.Material.Neon
        chev.Color = Color3.new(0.1, 0.1, 0.1)
        chev.Size = Vector3.new(size * 0.5, 0.2, 1.2)
        chev.CFrame = CFrame.lookAt(
            pos + Vector3.new(0, 0.71, 0) + dir * (i - 2) * 1.8,
            pos + Vector3.new(0, 0.71, 0) + dir * 10
        ) * CFrame.Angles(math.rad(-90), 0, 0)
        chev.Parent = folder
    end
    icon(pad, "LAUNCH", COLORS.pad)
    local land = Instance.new("Part")
    land.Name = "LandingZone" .. index
    land.Shape = Enum.PartType.Cylinder
    land.Anchored = true
    land.CanCollide = false
    land.CanQuery = false
    land.Material = Enum.Material.Neon
    land.Color = COLORS.pad
    land.Transparency = 0.6
    land.Size = Vector3.new(0.2, 8, 8)
    land.CFrame = CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
    land.Parent = folder

    -- trigger volume: larger than the visible pad, server-authoritative distance check
    local trig = { Center = pos + Vector3.new(0, 2, 0), Half = Vector3.new(size / 2 + 1, 2.5, size / 2 + 1) }
    if debug then
        local outline = Instance.new("Part")
        outline.Name = "LaunchTrigger" .. index
        outline.Anchored = true
        outline.CanCollide = false
        outline.CanQuery = false
        outline.Transparency = 0.75
        outline.Color = COLORS.pad
        outline.Material = Enum.Material.ForceField
        outline.Size = trig.Half * 2
        outline.CFrame = CFrame.new(trig.Center)
        outline.Parent = folder
        local v, flight = launchVelocity(pos, target, spec.vy or 62)
        -- direction arrow: a thin neon rod along the initial velocity
        local arrow = Instance.new("Part")
        arrow.Anchored = true
        arrow.CanCollide = false
        arrow.CanQuery = false
        arrow.Material = Enum.Material.Neon
        arrow.Color = Color3.new(1, 1, 1)
        arrow.Size = Vector3.new(0.3, 0.3, 12)
        arrow.CFrame = CFrame.lookAt(pos + Vector3.new(0, 2, 0), pos + Vector3.new(0, 2, 0) + v.Unit * 12)
            * CFrame.new(0, 0, -6)
        arrow.Parent = folder
        icon(land, ("LAND %.1fs"):format(flight), COLORS.pad)
    end
    table.insert(self.LaunchPads, { Spec = spec, Pos = pos, Target = target, Trigger = trig, Pad = pad, Cooldown = {} })
end

function PickupService:TryLaunch(padInfo, player)
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then
        return
    end
    local now = os.clock()
    if now - (padInfo.Cooldown[player] or 0) < 1.0 then
        return -- re-trigger protection
    end
    padInfo.Cooldown[player] = now
    local v, flight = launchVelocity(root.Position, padInfo.Target, padInfo.Spec.vy or 62)
    character:SetAttribute("Launched", true)
    self.Stats.LaunchUses += 1
    self.Client.Launch:Fire(player, v, flight)
    playSound(padInfo.Pad, "upload:LaunchPad", 1)
    local a0 = Instance.new("Attachment")
    a0.Parent = root
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -2, 0)
    a1.Parent = root
    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Color = ColorSequence.new(COLORS.pad)
    trail.Lifetime = 0.5
    trail.LightEmission = 1
    trail.Parent = root
    Debris:AddItem(trail, flight + 0.5)
    Debris:AddItem(a0, flight + 0.5)
    Debris:AddItem(a1, flight + 0.5)
    local diedConn
    diedConn = hum.Died:Connect(function()
        if character:GetAttribute("Launched") then
            self.Stats.LaunchDeathsInFlight += 1
        end
    end)
    task.delay(flight + 0.5, function()
        if character.Parent then
            character:SetAttribute("Launched", nil)
        end
        if diedConn then
            diedConn:Disconnect()
        end
    end)
end

-- ===== build for the current map =====
function PickupService:Build(layout)
    self:Clear()
    resetStats()
    local folder = Instance.new("Folder")
    folder.Name = "Pickups"
    folder.Parent = workspace
    self.Folder = folder
    self.Pickups = {}
    self.LaunchPads = {}
    for i, spec in layout.Pickups or {} do
        table.insert(self.Pickups, makePickup(folder, spec, i))
    end
    for i, spec in layout.LaunchPads or {} do
        makeLaunchPad(self, folder, spec, i)
    end

    -- bob + spin models; check touches by distance (robust on moving parts)
    local t0 = os.clock()
    self.Conn = RunService.Heartbeat:Connect(function()
        local t = os.clock() - t0
        for _, lp in self.LaunchPads do
            for _, player in Players:GetPlayers() do
                if player:GetAttribute("InMatch") then
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root and not player.Character:GetAttribute("Launched") then
                        local d = root.Position - lp.Trigger.Center
                        if
                            math.abs(d.X) <= lp.Trigger.Half.X
                            and math.abs(d.Y) <= lp.Trigger.Half.Y
                            and math.abs(d.Z) <= lp.Trigger.Half.Z
                        then
                            self:TryLaunch(lp, player)
                        end
                    end
                end
            end
        end
        for _, p in self.Pickups do
            if p.Model and p.Ready then
                p.Model:PivotTo(
                    CFrame.new(p.Pos + Vector3.new(0, 2.5 + math.sin(t * 2) * 0.3, 0)) * CFrame.Angles(0, t * 1.2, 0)
                )
            end
            if p.Ready then
                for _, player in Players:GetPlayers() do
                    if player:GetAttribute("InMatch") then
                        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                        if root and hum and hum.Health > 0 and (root.Position - p.Pos).Magnitude < 4 then
                            self:Collect(p, player)
                            break
                        end
                    end
                end
            end
        end
    end)
end

function PickupService:Collect(pickup, player)
    local kind = pickup.Kind
    local d = DEFAULTS[kind] or {}
    local character = player.Character
    if kind == "speed" then
        local last = player:GetAttribute("LastSpeedPickup") or -999
        if os.clock() - last < (pickup.Spec.cooldown or d.Cooldown) or character:GetAttribute("SpeedBoost") then
            return
        end
        player:SetAttribute("LastSpeedPickup", os.clock())
        self:GiveSpeed(player, pickup.Spec.multiplier or d.Multiplier, pickup.Spec.duration or d.Duration)
        self.Stats.SpeedUses += 1
        self.Client.Notice:Fire(player, "SPEED BOOST")
    elseif kind == "weapon" then
        self:GiveWeapon(player, pickup.Spec.weapon, pickup.Spec.duration or d.Duration)
        self.Stats.WeaponUses += 1
        self.Client.Notice:Fire(player, (pickup.Spec.weapon or "WEAPON"):upper() .. " PICKED UP")
    elseif kind == "jetpack" then
        self:GiveJetpack(player, pickup.Spec.fuel or d.Fuel)
        self.Stats.JetpackUses += 1
        self.Client.Notice:Fire(player, "JETPACK  hold Jump")
    end
    playSound(pickup.Pad, "upload:Pickup", 0.9)
    setReady(pickup, false, pickup.Respawn)
    task.spawn(function()
        local left = pickup.Respawn
        while left > 0 and pickup.Pad.Parent do
            task.wait(1)
            left -= 1
            if not pickup.Ready then
                setReady(pickup, false, left)
            end
        end
        if pickup.Pad.Parent then
            setReady(pickup, true)
        end
    end)
end

function PickupService:NoteDeath(position)
    for _, p in self.Pickups or {} do
        if (position - p.Pos).Magnitude < 12 then
            self.Stats.DeathsNearPickups += 1
            return
        end
    end
end

function PickupService:Clear()
    if self.Conn then
        self.Conn:Disconnect()
        self.Conn = nil
    end
    if self.Folder then
        self.Folder:Destroy()
        self.Folder = nil
    end
    self.Pickups = {}
    self.LaunchPads = {}
end

return PickupService
