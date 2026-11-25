-- Weapon test range. Builds the lanes, the dummies and the lobby entrance from Shared/Range,
-- hands out any gun on request, keeps the magazine full, and reports every dummy hit to the
-- player who fired it (RangeController draws the readout).
--
-- Damage reaches this service through WeaponService's damage callback: a hit on a dummy is
-- routed to OnDummyHit with the kit's falloff and our crit multiplier already applied, so the
-- number shown is the number a player would have taken. Dummies never take Humanoid damage;
-- their health is ours, which is what lets them stand back up and time a kill.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Range = require(ReplicatedStorage.Shared.Range)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local RangeService = Knit.CreateService({
    Name = "RangeService",
    Client = {
        Hit = Knit.CreateSignal(), -- (report) to the shooter, one per pellet
    },
})

local PAL = Range.Palette
local BAND_COLOR = { CLOSE = PAL.Close, MID = PAL.Mid, FAR = PAL.Far }

local function tuning(key)
    local t = ReplicatedStorage:FindFirstChild("Tuning")
    local v = t and t:GetAttribute("Range_" .. key)
    if type(v) == "number" and v > 0 then
        return v
    end
    return Config.Range[key]
end

local function world(p)
    local o = Range.Origin
    return Vector3.new(o[1] + p[1], o[2] + p[2], o[3] + p[3])
end

local function makePart(parent, name, cf, size, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = size
    part.CFrame = cf
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

-- Text painted on a part's face. A surface has its own backdrop, so no stroke.
local function surfaceText(part, face, text, color, pixelsPerStud)
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = pixelsPerStud or 30
    gui.Parent = part
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = color
    label.Parent = gui
    return label
end

local function prompt(part, action, object)
    local p = Instance.new("ProximityPrompt")
    p.ActionText = action
    p.ObjectText = object
    p.KeyboardKeyCode = Enum.KeyCode.E
    p.HoldDuration = 0
    p.MaxActivationDistance = 12
    p.RequiresLineOfSight = false
    p.Parent = part
    return p
end

-- ===== Build =====

function RangeService:BuildLanes(folder)
    local hw, back, front = Range.HalfWidth, Range.Back, Range.Front
    local length = front - back
    local midZ = (front + back) / 2

    makePart(folder, "Floor", CFrame.new(world({ 0, -1, midZ })), Vector3.new(hw * 2, 2, length), PAL.Floor)
    for side = -1, 1, 2 do
        makePart(folder, "Wall", CFrame.new(world({ side * (hw + 1), 10, midZ })), Vector3.new(2, 20, length), PAL.Wall)
    end
    makePart(folder, "BackWall", CFrame.new(world({ 0, 10, back - 1 })), Vector3.new(hw * 2 + 4, 20, 2), PAL.Wall)
    -- the backstop is tall: misses past the far dummy hit something instead of the sky
    makePart(folder, "Backstop", CFrame.new(world({ 0, 18, front + 1 })), Vector3.new(hw * 2 + 4, 36, 2), PAL.Wall)

    local firing = makePart(
        folder,
        "FiringLine",
        CFrame.new(world({ 0, 0.03, 0 })),
        Vector3.new(hw * 2, 0.06, 0.6),
        PAL.Accent,
        Enum.Material.Neon
    )
    firing.CanCollide = false

    -- distance lines every Marker studs, with the number painted at both edges
    for z = Range.Marker, front - 1, Range.Marker do
        local line =
            makePart(folder, "Marker" .. z, CFrame.new(world({ 0, 0.02, z })), Vector3.new(hw * 2, 0.04, 0.3), PAL.Line)
        line.CanCollide = false
        for side = -1, 1, 2 do
            local tag = makePart(
                folder,
                "MarkerTag" .. z,
                CFrame.new(world({ side * (hw - 3), 0.03, z - 2 })),
                Vector3.new(5, 0.05, 3),
                PAL.Floor
            )
            tag.CanCollide = false
            -- unrotated reads upright for someone facing +Z, down the lanes (the lobby's pad
            -- labels are turned 180 because the lobby faces the other way)
            surfaceText(tag, Enum.NormalId.Top, tostring(z), PAL.Line)
        end
    end

    -- one darker strip per lane, from the firing line to its dummy
    for _, lane in Range.Lanes do
        local strip = makePart(
            folder,
            "Lane" .. lane.distance,
            CFrame.new(world({ lane.x, 0.01, lane.distance / 2 })),
            Vector3.new(6, 0.02, lane.distance),
            PAL.Lane
        )
        strip.CanCollide = false
        local mark = makePart(
            folder,
            "LaneMark" .. lane.distance,
            CFrame.new(world({ lane.x, 0.04, -1.5 })),
            Vector3.new(6, 0.06, 2.4),
            PAL.Floor
        )
        mark.CanCollide = false
        surfaceText(mark, Enum.NormalId.Top, lane.distance .. " " .. lane.band, BAND_COLOR[lane.band])
    end

    local light = makePart(folder, "Light", CFrame.new(world({ 0, 30, 60 })), Vector3.new(1, 1, 1), PAL.Floor)
    light.Transparency = 1
    light.CanCollide = false
    light.CanQuery = false
    local point = Instance.new("PointLight")
    point.Range = 60
    point.Brightness = 1.2
    point.Parent = light
end

-- A blocky R15-proportioned target. Parts are named like a character's so the kit's headshot
-- check (part.Name == "Head") and getHumanoid (PrimaryPart named HumanoidRootPart) both work.
local function buildDummy(folder, lane, index)
    local model = Instance.new("Model")
    model.Name = ("Dummy%d"):format(lane.distance)
    local base = world({ lane.x, 0, lane.distance })
    -- facing the firing line
    local face = CFrame.lookAt(base, base - Vector3.new(0, 0, 1))
    local function piece(name, offset, size, color)
        local p = makePart(model, name, face * CFrame.new(offset), size, color)
        return p
    end
    local root = piece("HumanoidRootPart", Vector3.new(0, 3, 0), Vector3.new(2, 2, 1), PAL.Dummy)
    root.Transparency = 1
    root.CanCollide = false
    root.CanQuery = false -- shots land on the visible parts, not the invisible box around them
    piece("LeftLeg", Vector3.new(-0.5, 1, 0), Vector3.new(1, 2, 1), PAL.Dummy)
    piece("RightLeg", Vector3.new(0.5, 1, 0), Vector3.new(1, 2, 1), PAL.Dummy)
    piece("LowerTorso", Vector3.new(0, 2.2, 0), Vector3.new(2, 0.4, 1), PAL.Dummy)
    piece("UpperTorso", Vector3.new(0, 3.2, 0), Vector3.new(2, 1.6, 1), PAL.Dummy)
    piece("LeftArm", Vector3.new(-1.5, 3, 0), Vector3.new(1, 2, 1), PAL.Dummy)
    piece("RightArm", Vector3.new(1.5, 3, 0), Vector3.new(1, 2, 1), PAL.Dummy)
    local head = piece("Head", Vector3.new(0, 4.6, 0), Vector3.new(1.2, 1.2, 1.2), PAL.DummyHead)
    model.PrimaryPart = root

    local humanoid = Instance.new("Humanoid")
    humanoid.RequiresNeck = false
    humanoid.BreakJointsOnDeath = false
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    humanoid.Parent = model

    model:SetAttribute("RangeDummy", index)
    model.Parent = folder

    -- Name plate and health bar. Sized in studs and grown with distance so the 200-stud dummy is
    -- still readable from the firing line.
    local grow = math.max(1, lane.distance / 50)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Plate"
    gui.Size = UDim2.fromScale(4.5 * grow, 1.6 * grow)
    gui.StudsOffset = Vector3.new(0, 1.4 + 0.8 * grow, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 320
    gui.Parent = head
    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromScale(1, 0.55)
    title.BackgroundTransparency = 1
    title.TextScaled = true
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = BAND_COLOR[lane.band]
    title.Text = ("%d STUDS - %s"):format(lane.distance, lane.band)
    Palette.worldText(title)
    title.Parent = gui
    local track = Instance.new("Frame")
    track.Position = UDim2.fromScale(0.1, 0.65)
    track.Size = UDim2.fromScale(0.8, 0.3)
    track.BackgroundColor3 = PAL.Track
    track.BorderSizePixel = 0
    track.Parent = gui
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = PAL.Health
    fill.BorderSizePixel = 0
    fill.Parent = track
    local hpText = Instance.new("TextLabel")
    hpText.Size = UDim2.fromScale(1, 1)
    hpText.BackgroundTransparency = 1
    hpText.TextScaled = true
    hpText.Font = Enum.Font.GothamBold
    hpText.TextColor3 = PAL.Text
    Palette.worldText(hpText, 1)
    hpText.Parent = track

    return {
        Model = model,
        Lane = lane,
        Index = index,
        Head = head,
        Home = model:GetPivot(),
        Fill = fill,
        HpText = hpText,
        Health = tuning("DummyHealth"),
        FirstHit = nil,
        LastHit = 0,
        Hits = 0,
        DownUntil = nil,
    }
end

function RangeService:BuildEntrance(folder)
    local lobby = require(ReplicatedStorage.Shared.Maps.Lobby)
    local o = lobby.Origin
    local e = Range.Entrance
    local pos = Vector3.new(o[1] + e.pos[1], o[2] + e.pos[2], o[3] + e.pos[3])
    local size = Vector3.new(e.size[1], e.size[2], e.size[3])
    local pad = makePart(
        folder,
        "RangeEntrance",
        CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)),
        size,
        PAL.Accent,
        Enum.Material.Neon
    )
    pad.Transparency = 0.35
    surfaceText(pad, Enum.NormalId.Top, "WEAPON RANGE", PAL.Wall).Rotation = 180
    local sign = makePart(
        folder,
        "RangeEntranceSign",
        CFrame.new(pos + Vector3.new(0, 6, size.Z / 2 + 0.5)),
        Vector3.new(size.X, 4, 1),
        PAL.Wall
    )
    -- the lobby faces -Z, so the sign's readable face is its Front (-Z)
    surfaceText(sign, Enum.NormalId.Front, "WEAPON RANGE", PAL.Accent, 40)
    prompt(pad, "Enter", "Weapon Range").Triggered:Connect(function(player)
        self:Enter(player)
    end)
end

function RangeService:BuildExit(folder)
    local x = Range.Exit
    local pad = makePart(
        folder,
        "RangeExit",
        CFrame.new(world({ x.pos[1], x.pos[2] + x.size[2] / 2, x.pos[3] })),
        Vector3.new(x.size[1], x.size[2], x.size[3]),
        PAL.Accent,
        Enum.Material.Neon
    )
    pad.Transparency = 0.35
    -- read walking back toward it, facing -Z
    surfaceText(pad, Enum.NormalId.Top, "LOBBY", PAL.Wall).Rotation = 180
    prompt(pad, "Back to lobby", "Weapon Range").Triggered:Connect(function(player)
        self:Leave(player)
    end)
end

function RangeService:Build()
    local old = workspace:FindFirstChild("WeaponRange")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "WeaponRange"
    folder.Parent = workspace
    self.Folder = folder

    self:BuildLanes(folder)
    self:BuildExit(folder)
    self:BuildEntrance(folder)

    self.Dummies = {}
    self.ByModel = {}
    for i, lane in Range.Lanes do
        local dummy = buildDummy(folder, lane, i)
        self.Dummies[i] = dummy
        self.ByModel[dummy.Model] = dummy
        self:RefreshPlate(dummy)
    end
end

-- ===== Dummies =====

function RangeService:IsDummy(model)
    return model ~= nil and self.ByModel ~= nil and self.ByModel[model] ~= nil
end

function RangeService:RefreshPlate(dummy)
    local max = tuning("DummyHealth")
    local frac = math.clamp(dummy.Health / max, 0, 1)
    dummy.Fill.Size = UDim2.fromScale(frac, 1)
    dummy.Fill.BackgroundColor3 = frac > 0.35 and PAL.Health or PAL.HealthLow
    dummy.HpText.Text = dummy.DownUntil and "DOWN" or ("%d / %d"):format(math.ceil(dummy.Health), max)
end

local function tint(dummy, down)
    for _, part in dummy.Model:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if down then
                part.Color = PAL.DummyDown
            else
                part.Color = part.Name == "Head" and PAL.DummyHead or PAL.Dummy
            end
        end
    end
end

function RangeService:Reset(dummy)
    dummy.Health = tuning("DummyHealth")
    dummy.FirstHit = nil
    dummy.Hits = 0
    dummy.DownUntil = nil
    dummy.Model:PivotTo(dummy.Home)
    tint(dummy, false)
    self:RefreshPlate(dummy)
end

function RangeService:OnDummyHit(dealer, model, amount, headshot, hitInfo, tool)
    local dummy = self.ByModel[model]
    if not dummy or dummy.DownUntil then
        return
    end
    local stats = tool and Weapons[tool.Name]
    if not stats then
        return
    end
    local now = os.clock()
    local max = tuning("DummyHealth")
    if not dummy.FirstHit then
        dummy.FirstHit = now
        dummy.Hits = 0
    end
    dummy.Hits += 1
    dummy.LastHit = now
    dummy.Health = math.max(0, dummy.Health - amount)

    local distance = hitInfo and hitInfo.d
    if type(distance) ~= "number" then
        local root = dealer and dealer:IsA("Player") and dealer.Character and dealer.Character.PrimaryPart
        distance = root and (root.Position - dummy.Head.Position).Magnitude or dummy.Lane.distance
    end

    local down = dummy.Health <= 0
    local ttk = down and (now - dummy.FirstHit) or nil
    local hits = dummy.Hits
    if down then
        dummy.DownUntil = now + tuning("DownSeconds")
        -- tip it over backwards about its feet
        dummy.Model:PivotTo(
            dummy.Home * CFrame.new(0, -3, 0) * CFrame.Angles(math.rad(-75), 0, 0) * CFrame.new(0, 3, 0)
        )
        tint(dummy, true)
    end
    self:RefreshPlate(dummy)

    if dealer and dealer:IsA("Player") then
        local report = Range.report(stats, distance, headshot, amount)
        self.Client.Hit:Fire(dealer, {
            Lane = dummy.Index,
            Marked = dummy.Lane.distance,
            Band = dummy.Lane.band,
            Head = dummy.Head,
            Weapon = tool.Name,
            Distance = distance,
            Headshot = headshot,
            Damage = amount,
            Near = report.Near,
            Spec = report.Spec,
            Falloff = report.Falloff,
            Zone = report.Zone,
            Health = dummy.Health,
            MaxHealth = max,
            Down = down,
            TTK = ttk,
            Hits = hits,
        })
    end
end

function RangeService:Tick()
    local now = os.clock()
    for _, dummy in self.Dummies do
        if dummy.DownUntil then
            if now >= dummy.DownUntil then
                self:Reset(dummy)
            end
        elseif dummy.FirstHit and now - dummy.LastHit >= tuning("HealSeconds") then
            self:Reset(dummy)
        end
    end

    -- InRange follows where the player actually is, so a teleport into a match (or anything
    -- else that moves them out) ends range mode without the range having to be told.
    for _, player in Players:GetPlayers() do
        if player:GetAttribute("InRange") then
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root or not Range.inside(root.Position) then
                self:Exit(player, false)
            end
        end
    end
end

-- ===== Players =====

local function clearTools(player)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        backpack:ClearAllChildren()
    end
    local character = player.Character
    if character then
        for _, child in character:GetChildren() do
            if child:IsA("Tool") then
                child:Destroy()
            end
        end
    end
end

-- The kit takes a round off the server copy of CurrentAmmo on every shot (the client keeps its
-- own copy, which RangeController refills). Put it straight back while the player is in range.
local function keepFull(player, tool)
    task.spawn(function()
        local ammo = tool:WaitForChild("CurrentAmmo", 10)
        local config = tool:FindFirstChild("Configuration")
        local capacity = config and config:FindFirstChild("AmmoCapacity")
        if not ammo or not capacity then
            return
        end
        local conn = ammo.Changed:Connect(function()
            if player:GetAttribute("InRange") and ammo.Value < capacity.Value then
                ammo.Value = capacity.Value
            end
        end)
        tool.Destroying:Once(function()
            conn:Disconnect()
        end)
    end)
end

function RangeService:Give(player, name)
    local template = self.Tools:FindFirstChild(name)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not template or not humanoid or not backpack then
        return false
    end
    clearTools(player)
    local tool = template:Clone()
    Knit.GetService("SkinService"):Apply(tool, player)
    tool.Parent = backpack
    keepFull(player, tool)
    player:SetAttribute("RangeWeapon", name)
    task.delay(0.1, function()
        if humanoid.Health > 0 and tool.Parent == backpack then
            humanoid:EquipTool(tool)
        end
    end)
    return true
end

function RangeService:Enter(player)
    if player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed" then
        return false, "in_match"
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return false, "no_character"
    end
    -- spread arrivals along the firing line so two players do not land inside each other
    local pos = world(Range.Spawn) + Vector3.new((math.random() - 0.5) * 16, 0, 0)
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10))
    player:SetAttribute("InRange", true)

    local pick = player:GetAttribute("RangeWeapon")
    if not table.find(self.Guns, pick) then
        local primary = Knit.GetService("LoadoutService"):Get(player).Primary
        pick = table.find(self.Guns, primary) and primary or self.Guns[1]
    end
    if pick then
        self:Give(player, pick)
    end
    return true
end

-- Leave range mode. `teleport` sends them back to the lobby; the region check passes false
-- because whatever moved them out has already put them somewhere.
function RangeService:Exit(player, teleport)
    if not player:GetAttribute("InRange") then
        return
    end
    player:SetAttribute("InRange", false)
    if player:GetAttribute("InMatch") then
        return -- the match hands out its own loadout
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local spawns = Knit.GetService("MapService").LobbySpawns
    if teleport and root and spawns and #spawns > 0 then
        local pos = spawns[math.random(#spawns)] + Vector3.new(0, 3, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -10))
    end
    Knit.GetService("WeaponService"):GiveLoadout(player)
end

function RangeService:Leave(player)
    self:Exit(player, true)
end

-- ===== Client API =====

function RangeService.Client:GetGuns(_player)
    return self.Server.Guns
end

function RangeService.Client:Enter(player)
    return self.Server:Enter(player)
end

function RangeService.Client:Leave(player)
    self.Server:Leave(player)
    return true
end

function RangeService.Client:Equip(player, name)
    if not player:GetAttribute("InRange") or type(name) ~= "string" or not table.find(self.Server.Guns, name) then
        return false
    end
    return self.Server:Give(player, name)
end

function RangeService:KnitStart()
    self.Tools = ReplicatedStorage:WaitForChild("WeaponTools")
    self.Guns = Range.guns(Weapons, function(name)
        return self.Tools:FindFirstChild(name) ~= nil
    end)
    self:Build()

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            -- a new character spawns in the lobby
            player:SetAttribute("InRange", false)
        end)
    end)
    for _, player in Players:GetPlayers() do
        player.CharacterAdded:Connect(function()
            player:SetAttribute("InRange", false)
        end)
    end

    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc >= 0.25 then
            acc = 0
            self:Tick()
        end
    end)
end

return RangeService
