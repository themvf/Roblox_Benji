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
-- SYSTEM-WIDE RULE: ground markers communicate through their PERIMETER, not a saturated fill.
-- A neon disc reads as "look at me" when it only needs to say "something is here", and at pad
-- sizes it dominates the combat scene exactly the way the old objective disc did. Objectives,
-- pickups and launch pads all follow this now.
local function rimRing(folder, name, pos, radius, color, segments)
    local out = {}
    local n = segments or 28
    local seglen = (2 * math.pi * radius) / n * 1.2
    for i = 1, n do
        local angle = (i / n) * math.pi * 2
        local seg = Instance.new("Part")
        seg.Name = name .. "Rim" .. i
        seg.Anchored = true
        seg.CanCollide = false
        seg.CanQuery = false
        seg.Material = Enum.Material.Neon
        seg.Color = color
        seg.Size = Vector3.new(seglen, 0.3, 0.55)
        seg.CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * radius, 0.22, math.sin(angle) * radius))
            * CFrame.Angles(0, -angle, 0)
        seg.Parent = folder
        table.insert(out, seg)
    end
    return out
end

local function basePad(folder, name, pos, color)
    local pad = Instance.new("Part")
    pad.Name = name
    pad.Shape = Enum.PartType.Cylinder
    pad.Anchored = true
    pad.CanCollide = false
    pad.CanQuery = false
    pad.Material = Enum.Material.SmoothPlastic -- fill is context, not signal
    pad.Color = color
    pad.Transparency = 0.82
    pad.Size = Vector3.new(0.3, 5, 5)
    pad.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pad.Parent = folder
    rimRing(folder, name, pos, 2.5, color)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = 9
    light.Brightness = 0.8
    light.Parent = pad
    return pad
end

-- No word floats over a pickup: the 3D model on the pad already says what it is. All this adds
-- is a respawn bar, which fills as the pickup comes back and hides once it is ready.
local function timerBadge(parent, color)
    local bb = Instance.new("BillboardGui")
    bb.Name = "RespawnBar"
    bb.Size = UDim2.fromOffset(70, 8)
    bb.StudsOffset = Vector3.new(0, 4.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 120
    bb.Enabled = false
    bb.Parent = parent
    local back = Instance.new("Frame")
    back.Size = UDim2.fromScale(1, 1)
    back.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
    back.BorderSizePixel = 0
    back.Parent = bb
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = back
    return bb, fill
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
    local badge, badgeFill = timerBadge(pad, color)
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
        Badge = badge,
        BadgeFill = badgeFill,
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
    -- the bar fills toward ready, then disappears; the model coming back is the real signal
    if pickup.Badge then
        pickup.Badge.Enabled = not ready
        if not ready and secondsLeft then
            local total = pickup.Respawn or 30
            local done = math.clamp((total - secondsLeft) / total, 0, 1)
            pickup.BadgeFill.Size = UDim2.fromScale(done, 1)
        end
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
    pad.Material = Enum.Material.Fabric
    pad.Color = Color3.fromRGB(28, 35, 45)
    pad.Shape = Enum.PartType.Cylinder
    pad.Size = Vector3.new(0.6, size, size)
    pad.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    pad.Parent = folder
    -- Padded circular frame, exposed springs and legs read as a trampoline.
    for i = 1, 16 do
        local angle = i * math.pi / 8
        local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local rim = Instance.new("Part")
        rim.Name = "TrampolinePadding"
        rim.Size = Vector3.new(size * 0.21, 0.65, 0.75)
        rim.CFrame =
            CFrame.lookAt(pos + radial * (size / 2 + 0.1) + Vector3.new(0, 0.5, 0), pos + Vector3.new(0, 0.5, 0))
        rim.Color, rim.Material = COLORS.pad, Enum.Material.SmoothPlastic
        rim.Anchored, rim.CanCollide, rim.CanQuery = true, false, false
        rim.Parent = folder
        local spring = Instance.new("Part")
        spring.Name = "TrampolineSpring"
        spring.Size = Vector3.new(0.15, 0.15, 0.65)
        spring.CFrame =
            CFrame.lookAt(pos + radial * (size / 2 - 0.35) + Vector3.new(0, 0.65, 0), pos + Vector3.new(0, 0.65, 0))
        spring.Material, spring.Color = Enum.Material.Metal, Color3.fromRGB(170, 180, 190)
        spring.Anchored, spring.CanCollide, spring.CanQuery = true, false, false
        spring.Parent = folder
    end
    for _, x in { -1, 1 } do
        for _, z in { -1, 1 } do
            local leg = Instance.new("Part")
            leg.Name = "TrampolineLeg"
            leg.Size = Vector3.new(0.35, 0.6, 0.35)
            leg.Position = pos + Vector3.new(x * size * 0.32, 0, z * size * 0.32)
            leg.Anchored, leg.CanCollide, leg.CanQuery = true, false, false
            leg.Material = Enum.Material.Metal
            leg.Color = Color3.fromRGB(100, 110, 120)
            leg.Parent = folder
        end
    end
    local land = Instance.new("Part")
    land.Name = "LandingZone" .. index
    land.Shape = Enum.PartType.Cylinder
    land.Anchored = true
    land.CanCollide = false
    land.CanQuery = false
    land.Material = Enum.Material.SmoothPlastic
    land.Color = COLORS.pad
    land.Transparency = 0.88 -- perimeter does the work; see rimRing
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
        local v = launchVelocity(pos, target, spec.vy or 62)
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
