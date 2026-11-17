-- Server-authoritative drivable vehicles (Wave Runner, Black Army RHIB, Tactical Helicopter).
-- Spawns vehicles exclusively from layout.VehicleSpawns, owns occupancy, weapon-fire gating,
-- vehicle HP/destruction, respawn timers, and abandoned-vehicle cleanup.
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AssetRegistry = require(ReplicatedStorage.Shared.AssetRegistry)

local VehicleService = Knit.CreateService({
    Name = "VehicleService",
    Client = {
        VehicleStateChanged = Knit.CreateSignal(), -- model | nil, role ("Driver" | "Passenger") | nil
    },
})

local VEHICLE_SPECS = {
    WaveRunner = {
        maxHealth = 120,
        maxSpeed = 72,
        turnSpeed = 2.8,
        isAir = false,
        passengerFire = false,
        respawn = 10,
        abandonedReset = 25,
    },
    RHIB = {
        maxHealth = 300,
        maxSpeed = 50,
        turnSpeed = 1.9,
        isAir = false,
        passengerFire = true,
        respawn = 15,
        abandonedReset = 25,
    },
    Helicopter = {
        maxHealth = 350,
        maxSpeed = 88,
        turnSpeed = 1.8,
        isAir = true,
        passengerFire = false,
        respawn = 25,
        abandonedReset = 25,
    },
}

local COLORS = {
    BoatHull = Color3.fromRGB(28, 32, 38),
    BoatTube = Color3.fromRGB(48, 54, 62),
    Glass = Color3.fromRGB(90, 140, 170),
    WaveRunnerA = Color3.fromRGB(35, 195, 220),
    WaveRunnerB = Color3.fromRGB(95, 215, 70),
    Marker = Color3.fromRGB(255, 225, 65),
    HeliBody = Color3.fromRGB(62, 68, 74),
    HeliDark = Color3.fromRGB(38, 40, 44),
}

local activeFolder: Folder? = nil
local activeEntries = {} -- list of spawned vehicle state tables
local occupiedByPlayer = {} -- [Player] = { state, seat, conns }
local buildVersion = 0

local function makePart(parent, name, localCF, size, color, material, canCollide, transparency, shape)
    local part = Instance.new("Part")
    part.Name = name
    if shape then
        part.Shape = shape
    end
    part.Size = size
    part.CFrame = localCF
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.CanCollide = canCollide ~= false
    part.CanQuery = canCollide ~= false
    part.Transparency = transparency or 0
    part.Anchored = false
    part.Massless = true
    part.Parent = parent
    return part
end

local function makeWedge(parent, name, localCF, size, color, material, canCollide, transparency)
    local wedge = Instance.new("WedgePart")
    wedge.Name = name
    wedge.Size = size
    wedge.CFrame = localCF
    wedge.Color = color
    wedge.Material = material or Enum.Material.SmoothPlastic
    wedge.TopSurface = Enum.SurfaceType.Smooth
    wedge.BottomSurface = Enum.SurfaceType.Smooth
    wedge.CanCollide = canCollide ~= false
    wedge.CanQuery = canCollide ~= false
    wedge.Transparency = transparency or 0
    wedge.Anchored = false
    wedge.Massless = true
    wedge.Parent = parent
    return wedge
end

local function addBeaconLight(part, color, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = range or 16
    light.Brightness = brightness or 1.4
    light.Parent = part
end

local function weldTo(root, part)
    if part == root then
        return
    end
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = root
end

local function addSeat(model, root, name, offset, isDriver)
    local seat = Instance.new(isDriver and "VehicleSeat" or "Seat")
    seat.Name = name
    seat.Size = Vector3.new(2, 0.8, 2)
    seat.CFrame = root.CFrame * CFrame.new(offset)
    seat.Transparency = 1
    seat.CanCollide = false
    seat.CanTouch = true
    seat.Massless = true
    if isDriver then
        seat.HeadsUpDisplay = false
        seat.MaxSpeed = 0
        seat.Torque = 0
        seat.TurnSpeed = 0
    end
    seat.Parent = model
    weldTo(root, seat)

    -- The seat is invisible, and touching it was the only way in: nothing on screen said a
    -- vehicle could be boarded. The prompt only asks to sit; the Occupant handler in
    -- SpawnEntry still decides who is allowed and ejects anyone who is not.
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "BoardVehicle"
    prompt.ActionText = isDriver and "Drive" or "Ride"
    prompt.ObjectText = model.Name
    prompt.HoldDuration = 0.35
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = seat
    prompt.Triggered:Connect(function(player)
        local character = player.Character
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and seat.Occupant == nil then
            seat:Sit(hum)
        end
    end)
    seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        prompt.Enabled = seat.Occupant == nil
    end)
    return seat
end

local function attachPhysics(root, isAir)
    local att = Instance.new("Attachment")
    att.Name = "DriveAttachment"
    att.Parent = root

    local lv = Instance.new("LinearVelocity")
    lv.Name = "DriveVelocity"
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    lv.MaxAxesForce = isAir and Vector3.new(45000, 65000, 45000) or Vector3.new(45000, 55000, 45000)
    lv.VectorVelocity = Vector3.zero
    lv.Enabled = false
    lv.Parent = root

    local av = Instance.new("AngularVelocity")
    av.Name = "DriveTurn"
    av.Attachment0 = att
    av.RelativeTo = Enum.ActuatorRelativeTo.World
    av.MaxTorque = 45000
    av.AngularVelocity = Vector3.zero
    av.Enabled = false
    av.Parent = root

    local ao = Instance.new("AlignOrientation")
    ao.Name = "LevelAlign"
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.Attachment0 = att
    ao.RigidityEnabled = false
    ao.Responsiveness = 18
    ao.MaxTorque = 50000
    ao.CFrame = root.CFrame
    ao.Enabled = false
    ao.Parent = root
end

-- The clean low-poly wave runner: one MeshPart, 1,696 triangles, built by
-- tools/blender/build_military_wave_runner.py and uploaded as a Model. It is loaded once and
-- cached. If the load fails (asset not owned by this experience, no network) the older
-- EnvironmentArt template is used, and failing that the primitive craft. The asset id comes
-- from the registry, which tools/asset_generate.py publish rewrites on every new upload.
-- Its mounts are measured from the model's pivot (bottom centre of the keel) and are drawn on
-- assets/models/military-wave-runner/review/mounts.png. Change them with
-- `asset_generate.py brief military-wave-runner --mount ...` and rebuild, not here.
local waveRunnerAsset = AssetRegistry["military-wave-runner"]
local hullCentre = Vector3.new(table.unpack(waveRunnerAsset.mounts.HullCentre))
local CLEAN_WAVE_RUNNER = {
    AssetId = waveRunnerAsset.assetId,
    KeelBelowHull = hullCentre.Y, -- studs from the hull part's centre down to the keel; sets the waterline
    Seat = Vector3.new(table.unpack(waveRunnerAsset.mounts.DriverSeat)) - hullCentre, -- relative to the hull part
}
local cleanWaveRunner = nil -- MeshPart once loaded, false once the load has failed

local function loadCleanWaveRunner()
    if cleanWaveRunner ~= nil then
        return cleanWaveRunner or nil
    end
    cleanWaveRunner = false
    if not CLEAN_WAVE_RUNNER.AssetId then
        return nil -- built locally but not uploaded yet
    end
    local ok, loaded = pcall(function()
        return InsertService:LoadAsset(CLEAN_WAVE_RUNNER.AssetId)
    end)
    if not ok or not loaded then
        warn("[VehicleService] clean wave runner did not load, using the older model:", loaded)
        return nil
    end
    local mesh = loaded:FindFirstChildWhichIsA("MeshPart", true)
    if mesh then
        mesh.Name = "WaveRunnerBody"
        mesh.Parent = nil
        cleanWaveRunner = mesh
    else
        warn("[VehicleService] clean wave runner asset holds no MeshPart")
    end
    loaded:Destroy()
    return cleanWaveRunner or nil
end

-- The patrol RHIB: one MeshPart, about 2,100 triangles, built by tools/blender/build_patrol_rhib.py
-- and uploaded as a Model. Same arrangement as the wave runner: the id and mounts come from the
-- registry, the mesh is loaded once and cached, and if the load fails the block-built boat below
-- is used. Mounts are drawn on assets/models/patrol-rhib/review/mounts.png; change them with
-- `asset_generate.py brief patrol-rhib --mount ...` and rebuild, not here.
local rhibAsset = AssetRegistry["patrol-rhib"]
local rhibHullCentre = rhibAsset and Vector3.new(table.unpack(rhibAsset.mounts.HullCentre))
local CLEAN_RHIB = rhibAsset
    and {
        AssetId = rhibAsset.assetId,
        KeelBelowHull = rhibHullCentre.Y, -- the hull part rides at Y = 0.35, so this sets the draught
        Seat = Vector3.new(table.unpack(rhibAsset.mounts.DriverSeat)) - rhibHullCentre,
        -- Invisible collision, relative to the hull part. The deck block's top is the deck, so
        -- players stand where the floor is drawn; the collar blocks stop them walking through it.
        -- Both stop short of the bow, where the boat narrows and a box would poke out of it.
        Deck = Vector3.new(6.8, 1.1, 22),
        CollarOffset = Vector3.new(3.9, 0.9, 3),
        Collar = Vector3.new(2, 2, 19),
    }
local cleanRHIB = nil -- MeshPart once loaded, false once the load has failed

local function loadCleanRHIB()
    if cleanRHIB ~= nil then
        return cleanRHIB or nil
    end
    cleanRHIB = false
    if not CLEAN_RHIB or not CLEAN_RHIB.AssetId then
        return nil -- not in the registry, or built locally but not uploaded yet
    end
    local ok, loaded = pcall(function()
        return InsertService:LoadAsset(CLEAN_RHIB.AssetId)
    end)
    if not ok or not loaded then
        warn("[VehicleService] patrol RHIB did not load, using the block-built boat:", loaded)
        return nil
    end
    local mesh = loaded:FindFirstChildWhichIsA("MeshPart", true)
    if mesh then
        mesh.Name = "RHIBBody"
        mesh.Parent = nil
        cleanRHIB = mesh
    else
        warn("[VehicleService] patrol RHIB asset holds no MeshPart")
    end
    loaded:Destroy()
    return cleanRHIB or nil
end

local function findEnvironmentArtTemplate(name: string): Folder?
    local art = ServerStorage:FindFirstChild("EnvironmentArt")
    local folder = art and art:FindFirstChild(name)
    if folder and folder:IsA("Folder") then
        return folder
    end
    return nil
end

local function weldTemplateParts(model: Model, rootPart: BasePart, baseCF: CFrame, template: Folder)
    for _, tmpl in template:GetChildren() do
        if tmpl:IsA("BasePart") then
            local part = tmpl:Clone()
            part.CFrame = baseCF * tmpl.CFrame
            part.Anchored = false
            part.Massless = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Parent = model
            weldTo(rootPart, part)
        end
    end
end

-- All models are built facing -Z forward so VehicleSeat LookVector and yaw match cleanly.
local function buildWaveRunner(baseCF, accentColor)
    local model = Instance.new("Model")
    model.Name = "WaveRunner"

    local clean = loadCleanWaveRunner()
    if clean then
        local hull = makePart(
            model,
            "Hull",
            baseCF,
            Vector3.new(3.8, 1.2, 8.6),
            COLORS.BoatHull,
            Enum.Material.SmoothPlastic,
            true,
            1
        )
        hull.Massless = false
        hull.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.2, 0.1, 1, 1)
        model.PrimaryPart = hull

        -- A MeshPart's CFrame is the centre of its bounding box, so lift it by half its height
        -- from the keel line. Its own rotation is kept in case the import left one on it.
        local body = clean:Clone()
        local rot = body.CFrame.Rotation
        local size = body.Size
        local tall = math.abs(rot.RightVector.Y) * size.X
            + math.abs(rot.UpVector.Y) * size.Y
            + math.abs(rot.LookVector.Y) * size.Z
        body.CFrame = baseCF * CFrame.new(0, tall / 2 - CLEAN_WAVE_RUNNER.KeelBelowHull, 0) * rot
        body.Anchored = false
        body.Massless = true
        body.CanCollide = false
        body.CanQuery = false
        body.CanTouch = false
        body.Parent = model
        weldTo(hull, body)

        local driverSeat = addSeat(model, hull, "DriverSeat", CLEAN_WAVE_RUNNER.Seat, true)
        attachPhysics(hull, false)
        return model, hull, { driverSeat }
    end

    local template = findEnvironmentArtTemplate("MilitaryWaveRunner")
    if template then
        local hull = makePart(
            model,
            "Hull",
            baseCF,
            Vector3.new(3.8, 1.2, 8.6),
            COLORS.BoatHull,
            Enum.Material.SmoothPlastic,
            true,
            1
        )
        hull.Massless = false
        hull.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.2, 0.1, 1, 1)
        model.PrimaryPart = hull

        weldTemplateParts(model, hull, baseCF, template)

        local driverSeat = addSeat(model, hull, "DriverSeat", Vector3.new(0, 1.55, 1.05), true)
        attachPhysics(hull, false)
        return model, hull, { driverSeat }
    end

    local hull =
        makePart(model, "Hull", baseCF, Vector3.new(2.8, 1.0, 7.2), COLORS.BoatHull, Enum.Material.SmoothPlastic)
    hull.Massless = false
    hull.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.2, 0.1, 1, 1)
    model.PrimaryPart = hull

    local dash = makePart(
        model,
        "DashGauge",
        baseCF * CFrame.new(0, 1.38, -1.55) * CFrame.Angles(math.rad(-25), 0, 0),
        Vector3.new(0.75, 0.28, 0.12),
        COLORS.Marker,
        Enum.Material.Neon,
        false
    )
    local parts = {
        makeWedge(model, "BowNose", baseCF * CFrame.new(0, 0.08, -4.55), Vector3.new(2.2, 1.15, 2.1), accentColor),
        makePart(model, "DeckTrimL", baseCF * CFrame.new(-1.25, 0.45, -0.3), Vector3.new(0.45, 0.35, 6.2), accentColor),
        makePart(model, "DeckTrimR", baseCF * CFrame.new(1.25, 0.45, -0.3), Vector3.new(0.45, 0.35, 6.2), accentColor),
        makePart(model, "FrontHood", baseCF * CFrame.new(0, 0.65, -2.2), Vector3.new(2.2, 0.55, 2.4), accentColor),
        makeWedge(model, "HoodSlope", baseCF * CFrame.new(0, 1.1, -1.65), Vector3.new(1.6, 0.75, 1.5), COLORS.BoatHull),
        makePart(model, "SeatBolster", baseCF * CFrame.new(0, 0.8, 0.8), Vector3.new(1.3, 0.72, 3.3), COLORS.BoatTube),
        makePart(model, "SeatTail", baseCF * CFrame.new(0, 0.95, 2.55), Vector3.new(1.3, 0.42, 0.7), accentColor),
        makePart(
            model,
            "Handlebar",
            baseCF * CFrame.new(0, 1.58, -1.18),
            Vector3.new(2.3, 0.22, 0.24),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(model, "GripL", baseCF * CFrame.new(-1.05, 1.58, -1.12), Vector3.new(0.4, 0.28, 0.32), COLORS.Marker),
        makePart(model, "GripR", baseCF * CFrame.new(1.05, 1.58, -1.12), Vector3.new(0.4, 0.28, 0.32), COLORS.Marker),
        makePart(
            model,
            "JetNozzle",
            baseCF * CFrame.new(0, -0.1, 3.75) * CFrame.Angles(math.rad(90), 0, 0),
            Vector3.new(0.65, 0.7, 0.65),
            COLORS.HeliDark,
            Enum.Material.Metal,
            false,
            0,
            Enum.PartType.Cylinder
        ),
        dash,
    }
    for _, p in parts do
        weldTo(hull, p)
    end

    local driverSeat = addSeat(model, hull, "DriverSeat", Vector3.new(0, 1.25, 0.5), true)
    attachPhysics(hull, false)
    return model, hull, { driverSeat }
end

local function buildRHIB(baseCF)
    local model = Instance.new("Model")
    model.Name = "RHIB"

    local clean = loadCleanRHIB()
    if clean then
        local hull =
            makePart(model, "Hull", baseCF, CLEAN_RHIB.Deck, COLORS.BoatHull, Enum.Material.SmoothPlastic, true, 1)
        hull.Massless = false
        -- Four times the old hull's volume, so a quarter of its density keeps the same drive feel.
        hull.CustomPhysicalProperties = PhysicalProperties.new(0.15, 0.2, 0.1, 1, 1)
        model.PrimaryPart = hull

        for _, side in { 1, -1 } do
            local offset = CLEAN_RHIB.CollarOffset * Vector3.new(side, 1, 1)
            local collar = makePart(
                model,
                side == 1 and "CollarR" or "CollarL",
                baseCF * CFrame.new(offset),
                CLEAN_RHIB.Collar,
                COLORS.BoatTube,
                Enum.Material.SmoothPlastic,
                true,
                1
            )
            weldTo(hull, collar)
        end

        -- A MeshPart's CFrame is the centre of its bounding box, so lift it by half its height
        -- from the keel line. Its own rotation is kept in case the import left one on it.
        local body = clean:Clone()
        local rot = body.CFrame.Rotation
        local size = body.Size
        local tall = math.abs(rot.RightVector.Y) * size.X
            + math.abs(rot.UpVector.Y) * size.Y
            + math.abs(rot.LookVector.Y) * size.Z
        body.CFrame = baseCF * CFrame.new(0, tall / 2 - CLEAN_RHIB.KeelBelowHull, 0) * rot
        body.Anchored = false
        body.Massless = true
        body.CanCollide = false
        body.CanQuery = false
        body.CanTouch = false
        body.Parent = model
        weldTo(hull, body)

        -- One working seat for now: the helm. Passenger seats come back when they are asked for.
        local driverSeat = addSeat(model, hull, "DriverSeat", CLEAN_RHIB.Seat, true)
        attachPhysics(hull, false)
        return model, hull, { driverSeat }
    end

    local hull = makePart(model, "Hull", baseCF, Vector3.new(4.3, 1.35, 12.2), COLORS.BoatHull, Enum.Material.Metal)
    hull.Massless = false
    hull.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.2, 0.1, 1, 1)
    model.PrimaryPart = hull

    local bowHeadlight = makePart(
        model,
        "BowSearchlight",
        baseCF * CFrame.new(0, 1.35, -7.2),
        Vector3.new(0.6, 0.35, 0.3),
        Color3.fromRGB(255, 240, 200),
        Enum.Material.Neon,
        false
    )
    addBeaconLight(bowHeadlight, Color3.fromRGB(255, 240, 200), 26, 1.5)

    local archStrobe = makePart(
        model,
        "ArchStrobe",
        baseCF * CFrame.new(0, 3.7, 4.8),
        Vector3.new(0.45, 0.45, 0.45),
        Color3.fromRGB(255, 185, 65),
        Enum.Material.Neon,
        false,
        0,
        Enum.PartType.Ball
    )
    addBeaconLight(archStrobe, Color3.fromRGB(255, 185, 65), 18, 1.2)

    local parts = {
        makeWedge(
            model,
            "BowStem",
            baseCF * CFrame.new(0, 0.18, -7.5),
            Vector3.new(3.8, 1.55, 3.0),
            COLORS.BoatHull,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "ForeDeck",
            baseCF * CFrame.new(0, 0.78, -5.2),
            Vector3.new(3.6, 0.35, 2.8),
            COLORS.BoatTube,
            Enum.Material.DiamondPlate
        ),
        makePart(
            model,
            "TubeL",
            baseCF * CFrame.new(-2.35, 0.55, -0.1) * CFrame.Angles(math.rad(90), 0, 0),
            Vector3.new(1.15, 12.0, 1.15),
            COLORS.BoatTube,
            Enum.Material.SmoothPlastic,
            true,
            0,
            Enum.PartType.Cylinder
        ),
        makePart(
            model,
            "TubeR",
            baseCF * CFrame.new(2.35, 0.55, -0.1) * CFrame.Angles(math.rad(90), 0, 0),
            Vector3.new(1.15, 12.0, 1.15),
            COLORS.BoatTube,
            Enum.Material.SmoothPlastic,
            true,
            0,
            Enum.PartType.Cylinder
        ),
        makePart(
            model,
            "BowTubeL",
            baseCF * CFrame.new(-1.35, 0.72, -6.9) * CFrame.Angles(0, math.rad(34), 0),
            Vector3.new(1.0, 1.0, 3.0),
            COLORS.BoatTube
        ),
        makePart(
            model,
            "BowTubeR",
            baseCF * CFrame.new(1.35, 0.72, -6.9) * CFrame.Angles(0, math.rad(-34), 0),
            Vector3.new(1.0, 1.0, 3.0),
            COLORS.BoatTube
        ),
        makePart(
            model,
            "Console",
            baseCF * CFrame.new(0, 1.55, -0.7),
            Vector3.new(2.0, 2.0, 2.0),
            COLORS.BoatHull,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "HelmWheel",
            baseCF * CFrame.new(0, 1.95, 0.38) * CFrame.Angles(math.rad(25), 0, 0),
            Vector3.new(0.85, 0.85, 0.16),
            COLORS.Marker,
            Enum.Material.Metal,
            false,
            0,
            Enum.PartType.Cylinder
        ),
        makeWedge(
            model,
            "Windshield",
            baseCF * CFrame.new(0, 2.75, -1.25),
            Vector3.new(1.9, 1.05, 1.2),
            COLORS.Glass,
            Enum.Material.Glass,
            false,
            0.35
        ),
        makePart(
            model,
            "BenchRear",
            baseCF * CFrame.new(0, 0.9, 3.0),
            Vector3.new(3.4, 0.4, 1.5),
            COLORS.BoatTube,
            Enum.Material.DiamondPlate
        ),
        makePart(
            model,
            "ArchL",
            baseCF * CFrame.new(-1.75, 2.0, 4.8),
            Vector3.new(0.45, 2.7, 0.55),
            COLORS.BoatHull,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "ArchR",
            baseCF * CFrame.new(1.75, 2.0, 4.8),
            Vector3.new(0.45, 2.7, 0.55),
            COLORS.BoatHull,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "ArchTop",
            baseCF * CFrame.new(0, 3.38, 4.8),
            Vector3.new(4.0, 0.35, 0.7),
            COLORS.BoatHull,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "Antenna",
            baseCF * CFrame.new(1.6, 4.5, 4.8),
            Vector3.new(0.1, 2.2, 0.1),
            COLORS.HeliDark,
            Enum.Material.Metal,
            false
        ),
        makePart(
            model,
            "EngineL",
            baseCF * CFrame.new(-1.0, 0.5, 6.55),
            Vector3.new(1.05, 1.85, 1.4),
            COLORS.BoatTube,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "EngineR",
            baseCF * CFrame.new(1.0, 0.5, 6.55),
            Vector3.new(1.05, 1.85, 1.4),
            COLORS.BoatTube,
            Enum.Material.Metal
        ),
        bowHeadlight,
        archStrobe,
    }
    for _, p in parts do
        weldTo(hull, p)
    end

    -- 1 driver + 3 armed passenger seats
    local driverSeat = addSeat(model, hull, "DriverSeat", Vector3.new(0, 1.2, 1.2), true)
    local passFront = addSeat(model, hull, "PassengerFront", Vector3.new(0, 1.2, -3.5), false)
    local passLeft = addSeat(model, hull, "PassengerLeft", Vector3.new(-1.25, 1.2, 3.0), false)
    local passRight = addSeat(model, hull, "PassengerRight", Vector3.new(1.25, 1.2, 3.0), false)

    attachPhysics(hull, false)
    return model, hull, { driverSeat, passFront, passLeft, passRight }
end

local function buildHelicopter(baseCF)
    local model = Instance.new("Model")
    model.Name = "Helicopter"

    local template = findEnvironmentArtTemplate("BlackHawk")
    if template then
        local floor = makePart(
            model,
            "Floor",
            baseCF * CFrame.new(0, 1.8, -1.2),
            Vector3.new(5.2, 3.4, 15.0),
            COLORS.HeliBody,
            Enum.Material.Metal,
            true,
            1
        )
        floor.Massless = false
        floor.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.1, 1, 1)
        model.PrimaryPart = floor

        weldTemplateParts(model, floor, baseCF, template)

        local searchLight = makePart(
            model,
            "SearchLight",
            baseCF * CFrame.new(0, 0.85, -10.5),
            Vector3.new(0.7, 0.4, 0.45),
            Color3.fromRGB(255, 245, 215),
            Enum.Material.Neon,
            false
        )
        addBeaconLight(searchLight, Color3.fromRGB(255, 245, 215), 36, 2.0)

        local navRed = makePart(
            model,
            "NavRed",
            baseCF * CFrame.new(-3.2, 2.2, -1.8),
            Vector3.new(0.28, 0.28, 0.28),
            Color3.fromRGB(255, 65, 65),
            Enum.Material.Neon,
            false,
            0,
            Enum.PartType.Ball
        )
        local navGreen = makePart(
            model,
            "NavGreen",
            baseCF * CFrame.new(3.2, 2.2, -1.8),
            Vector3.new(0.28, 0.28, 0.28),
            Color3.fromRGB(65, 255, 120),
            Enum.Material.Neon,
            false,
            0,
            Enum.PartType.Ball
        )
        local tailStrobe = makePart(
            model,
            "TailStrobe",
            baseCF * CFrame.new(0, 7.8, 12.2),
            Vector3.new(0.32, 0.32, 0.32),
            Color3.fromRGB(255, 185, 65),
            Enum.Material.Neon,
            false,
            0,
            Enum.PartType.Ball
        )
        addBeaconLight(tailStrobe, Color3.fromRGB(255, 185, 65), 16, 1.2)

        for _, p in { searchLight, navRed, navGreen, tailStrobe } do
            weldTo(floor, p)
        end

        -- 1 pilot + 3 transport-only passenger seats aligned with cockpit & cabin doorways
        local pilotSeat = addSeat(model, floor, "DriverSeat", Vector3.new(0, 0.2, -5.0), true)
        local passL = addSeat(model, floor, "PassengerLeft", Vector3.new(-2.4, 0.1, -1.0), false)
        local passR = addSeat(model, floor, "PassengerRight", Vector3.new(2.4, 0.1, -1.0), false)
        local passRear = addSeat(model, floor, "PassengerRear", Vector3.new(0, 0.1, 0.8), false)
        for _, s in { pilotSeat, passL, passR, passRear } do
            s.Size = Vector3.new(2.6, 1.4, 2.6)
        end

        attachPhysics(floor, true)
        return model, floor, { pilotSeat, passL, passR, passRear }
    end

    -- Open-sided troop cabin floor as PrimaryPart so all 4 seats sit cleanly without clipping walls
    local floor = makePart(
        model,
        "Floor",
        baseCF * CFrame.new(0, 1.0, 0),
        Vector3.new(5.0, 0.6, 11.0),
        COLORS.HeliBody,
        Enum.Material.Metal
    )
    floor.Massless = false
    floor.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.1, 1, 1)
    model.PrimaryPart = floor

    local searchLight = makePart(
        model,
        "SearchLight",
        baseCF * CFrame.new(0, 0.72, -5.6),
        Vector3.new(0.8, 0.45, 0.5),
        Color3.fromRGB(255, 245, 215),
        Enum.Material.Neon,
        false
    )
    addBeaconLight(searchLight, Color3.fromRGB(255, 245, 215), 36, 2.0)

    local navRed = makePart(
        model,
        "NavStrobeL",
        baseCF * CFrame.new(-3.4, 2.2, 0.2),
        Vector3.new(0.35, 0.35, 0.35),
        Color3.fromRGB(255, 65, 65),
        Enum.Material.Neon,
        false,
        0,
        Enum.PartType.Ball
    )
    local navGreen = makePart(
        model,
        "NavStrobeR",
        baseCF * CFrame.new(3.4, 2.2, 0.2),
        Vector3.new(0.35, 0.35, 0.35),
        Color3.fromRGB(65, 255, 120),
        Enum.Material.Neon,
        false,
        0,
        Enum.PartType.Ball
    )
    local tailStrobe = makePart(
        model,
        "TailStrobe",
        baseCF * CFrame.new(0, 6.95, 16.4),
        Vector3.new(0.4, 0.4, 0.4),
        Color3.fromRGB(255, 185, 65),
        Enum.Material.Neon,
        false,
        0,
        Enum.PartType.Ball
    )
    addBeaconLight(tailStrobe, Color3.fromRGB(255, 185, 65), 16, 1.2)

    local parts = {
        makePart(
            model,
            "SkidL",
            baseCF * CFrame.new(-2.1, 0.25, -0.4),
            Vector3.new(0.42, 0.42, 11.4),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "SkidR",
            baseCF * CFrame.new(2.1, 0.25, -0.4),
            Vector3.new(0.42, 0.42, 11.4),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "StrutFL",
            baseCF * CFrame.new(-2.0, 0.65, -2.8) * CFrame.Angles(0, 0, math.rad(-10)),
            Vector3.new(0.32, 0.85, 0.32),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "StrutFR",
            baseCF * CFrame.new(2.0, 0.65, -2.8) * CFrame.Angles(0, 0, math.rad(10)),
            Vector3.new(0.32, 0.85, 0.32),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "StrutBL",
            baseCF * CFrame.new(-2.0, 0.65, 2.8) * CFrame.Angles(0, 0, math.rad(-10)),
            Vector3.new(0.32, 0.85, 0.32),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "StrutBR",
            baseCF * CFrame.new(2.0, 0.65, 2.8) * CFrame.Angles(0, 0, math.rad(10)),
            Vector3.new(0.32, 0.85, 0.32),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "Nose",
            baseCF * CFrame.new(0, 1.85, -4.5),
            Vector3.new(4.5, 1.8, 2.4),
            COLORS.HeliBody,
            Enum.Material.Metal
        ),
        makeWedge(
            model,
            "NoseCone",
            baseCF * CFrame.new(0, 1.75, -6.5),
            Vector3.new(4.1, 1.6, 1.8),
            COLORS.HeliBody,
            Enum.Material.Metal
        ),
        makeWedge(
            model,
            "Canopy",
            baseCF * CFrame.new(0, 3.65, -4.6),
            Vector3.new(4.1, 1.85, 3.2),
            COLORS.Glass,
            Enum.Material.Glass,
            false,
            0.35
        ),
        makePart(
            model,
            "CanopyFrameL",
            baseCF * CFrame.new(-2.05, 3.55, -4.1) * CFrame.Angles(math.rad(-26), 0, 0),
            Vector3.new(0.28, 2.1, 0.32),
            COLORS.HeliDark,
            Enum.Material.Metal,
            false
        ),
        makePart(
            model,
            "CanopyFrameR",
            baseCF * CFrame.new(2.05, 3.55, -4.1) * CFrame.Angles(math.rad(-26), 0, 0),
            Vector3.new(0.28, 2.1, 0.32),
            COLORS.HeliDark,
            Enum.Material.Metal,
            false
        ),
        makePart(
            model,
            "StubWingL",
            baseCF * CFrame.new(-2.9, 2.1, 0.2),
            Vector3.new(1.4, 0.38, 2.2),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "StubWingR",
            baseCF * CFrame.new(2.9, 2.1, 0.2),
            Vector3.new(1.4, 0.38, 2.2),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "RearBulkhead",
            baseCF * CFrame.new(0, 2.8, 4.8),
            Vector3.new(4.8, 3.2, 1.0),
            COLORS.HeliBody,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "Roof",
            baseCF * CFrame.new(0, 4.65, 0.2),
            Vector3.new(4.8, 0.65, 9.6),
            COLORS.HeliBody,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "TurbineL",
            baseCF * CFrame.new(-1.35, 5.15, 1.6) * CFrame.Angles(math.rad(90), 0, 0),
            Vector3.new(1.25, 4.2, 1.25),
            COLORS.HeliDark,
            Enum.Material.Metal,
            false,
            0,
            Enum.PartType.Cylinder
        ),
        makePart(
            model,
            "TurbineR",
            baseCF * CFrame.new(1.35, 5.15, 1.6) * CFrame.Angles(math.rad(90), 0, 0),
            Vector3.new(1.25, 4.2, 1.25),
            COLORS.HeliDark,
            Enum.Material.Metal,
            false,
            0,
            Enum.PartType.Cylinder
        ),
        makePart(
            model,
            "TailBoom",
            baseCF * CFrame.new(0, 3.5, 10.9),
            Vector3.new(1.1, 1.3, 11.6),
            COLORS.HeliBody,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "TailHoriz",
            baseCF * CFrame.new(0, 3.6, 13.8),
            Vector3.new(4.2, 0.25, 1.2),
            COLORS.HeliDark,
            Enum.Material.Metal,
            false
        ),
        makeWedge(
            model,
            "TailFin",
            baseCF * CFrame.new(0, 5.3, 15.9) * CFrame.Angles(0, math.rad(180), 0),
            Vector3.new(0.4, 3.1, 2.2),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        makePart(
            model,
            "TailRotorHub",
            baseCF * CFrame.new(0.45, 5.1, 16.0),
            Vector3.new(0.2, 2.6, 0.32),
            COLORS.Marker,
            Enum.Material.Metal,
            false
        ),
        makePart(
            model,
            "RotorMast",
            baseCF * CFrame.new(0, 5.3, 0),
            Vector3.new(0.65, 0.9, 0.65),
            COLORS.HeliDark,
            Enum.Material.Metal
        ),
        searchLight,
        navRed,
        navGreen,
        tailStrobe,
    }
    for _, p in parts do
        weldTo(floor, p)
    end

    -- Spin-capable rotor assembly welded to RotorMast via RotorWeld
    local rotorA = makePart(
        model,
        "RotorA",
        baseCF * CFrame.new(0, 5.65, 0),
        Vector3.new(22, 0.18, 1.0),
        COLORS.HeliDark,
        Enum.Material.Metal,
        false
    )
    local rotorB = makePart(
        model,
        "RotorB",
        baseCF * CFrame.new(0, 5.65, 0),
        Vector3.new(1.0, 0.18, 22),
        COLORS.HeliDark,
        Enum.Material.Metal,
        false
    )
    weldTo(rotorA, rotorB)
    local mast = model:FindFirstChild("RotorMast")
    if mast then
        local rotorWeld = Instance.new("Weld")
        rotorWeld.Name = "RotorWeld"
        rotorWeld.Part0 = mast
        rotorWeld.Part1 = rotorA
        rotorWeld.C0 = CFrame.new(0, 0.45, 0)
        rotorWeld.Parent = mast
    end

    -- 1 pilot + 3 transport-only passenger seats
    local pilotSeat = addSeat(model, floor, "DriverSeat", Vector3.new(0, 0.8, -2.2), true)
    local passL = addSeat(model, floor, "PassengerLeft", Vector3.new(-1.3, 0.8, 0.8), false)
    local passR = addSeat(model, floor, "PassengerRight", Vector3.new(1.3, 0.8, 0.8), false)
    local passRear = addSeat(model, floor, "PassengerRear", Vector3.new(0, 0.8, 2.8), false)

    attachPhysics(floor, true)
    return model, floor, { pilotSeat, passL, passR, passRear }
end

local function clearOccupant(player)
    local rec = occupiedByPlayer[player]
    if not rec then
        return
    end
    occupiedByPlayer[player] = nil
    for _, conn in rec.conns do
        conn:Disconnect()
    end
    if player.Parent then
        player:SetAttribute("VehicleNoFire", nil)
    end
    VehicleService.Client.VehicleStateChanged:Fire(player, nil, nil)
end

local function ejectSeat(seat)
    local hum = seat.Occupant
    if hum then
        local char = hum.Parent
        hum.Sit = false
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = root.CFrame + Vector3.new(0, 4, 0)
        end
    end
end

local function anyOccupant(state)
    for _, seat in state.seats do
        if seat.Occupant ~= nil then
            return true
        end
    end
    return false
end

local function setAnchored(state, anchored)
    if state.root and state.root.Parent then
        state.root.Anchored = anchored
        local lv = state.root:FindFirstChild("DriveVelocity")
        local av = state.root:FindFirstChild("DriveTurn")
        local ao = state.root:FindFirstChild("LevelAlign")
        if lv then
            lv.Enabled = not anchored
            if anchored then
                lv.VectorVelocity = Vector3.zero
            end
        end
        if av then
            av.Enabled = not anchored
            if anchored then
                av.AngularVelocity = Vector3.zero
            end
        end
        if ao then
            ao.Enabled = not anchored
        end
    end
end

local function destroyAndRespawn(state, delaySeconds, explode)
    if state.destroying then
        return
    end
    state.destroying = true
    for _, seat in state.seats do
        ejectSeat(seat)
    end
    local model = state.model
    if model and model.Parent then
        if explode and state.root and state.root.Parent then
            local fx = Instance.new("Explosion")
            fx.BlastPressure = 0
            fx.BlastRadius = 0
            fx.DestroyJointRadiusPercent = 0
            fx.Position = state.root.Position
            fx.Parent = workspace
        end
        task.delay(explode and 0.4 or 0, function()
            if model.Parent then
                model:Destroy()
            end
        end)
    end
    local myVersion = state.version
    task.delay(delaySeconds, function()
        if buildVersion ~= myVersion or not activeFolder or not activeFolder.Parent then
            return
        end
        VehicleService:SpawnEntry(state.spawnConfig, myVersion)
    end)
end

function VehicleService:SpawnEntry(cfg, version)
    if version ~= buildVersion or not activeFolder or not activeFolder.Parent then
        return
    end
    local spec = VEHICLE_SPECS[cfg.kind]
    local baseCF = CFrame.new(cfg.pos[1], cfg.pos[2], cfg.pos[3]) * CFrame.Angles(0, math.rad(cfg.yaw or 0), 0)
    local model, root, seats
    if cfg.kind == "WaveRunner" then
        local accent = cfg.accentIndex == 2 and COLORS.WaveRunnerB or COLORS.WaveRunnerA
        model, root, seats = buildWaveRunner(baseCF, accent)
    elseif cfg.kind == "RHIB" then
        model, root, seats = buildRHIB(baseCF)
    elseif cfg.kind == "Helicopter" then
        model, root, seats = buildHelicopter(baseCF)
    else
        return
    end

    model.Name = cfg.name
    model:SetAttribute("IsVehicle", true)
    model:SetAttribute("VehicleType", cfg.kind)
    model:SetAttribute("HomeTeam", cfg.team)
    model:SetAttribute("MaxSpeed", spec.maxSpeed)
    model:SetAttribute("TurnSpeed", spec.turnSpeed)
    model:SetAttribute("PassengerFire", cfg.passengerFire == true)

    local hum = Instance.new("Humanoid")
    hum.Name = "VehicleHealth"
    hum.MaxHealth = cfg.maxHealth or spec.maxHealth
    hum.Health = hum.MaxHealth
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.BreakJointsOnDeath = false
    hum.EvaluateStateMachine = false
    hum.Parent = model

    model.Parent = activeFolder

    local state = {
        version = version,
        spawnConfig = cfg,
        kind = cfg.kind,
        team = cfg.team,
        passengerFire = cfg.passengerFire == true,
        respawn = cfg.respawn or spec.respawn,
        abandonedReset = cfg.abandonedReset or spec.abandonedReset,
        homePos = Vector3.new(cfg.pos[1], cfg.pos[2], cfg.pos[3]),
        atHome = true,
        lastOccupied = os.clock(),
        model = model,
        root = root,
        seats = seats,
        humanoid = hum,
        driver = nil,
        destroying = false,
    }
    table.insert(activeEntries, state)

    -- Park anchored at spawn so waves/collisions never push unattended rides off the dock
    setAnchored(state, true)

    hum.Died:Connect(function()
        destroyAndRespawn(state, state.respawn, true)
    end)

    for _, seat in seats do
        local isDriver = seat:IsA("VehicleSeat")
        seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            local occupantHum = seat.Occupant
            if occupantHum then
                local char = occupantHum.Parent
                local player = char and Players:GetPlayerFromCharacter(char)
                if not player then
                    occupantHum.Sit = false
                    return
                end
                local exploring = player:GetAttribute("Exploring") == true
                local inMatch = player:GetAttribute("InMatch") == true
                local teamOk = (not state.atHome) or (player:GetAttribute("Team") == state.team)
                if not exploring and not (inMatch and teamOk) then
                    occupantHum.Sit = false
                    return
                end

                clearOccupant(player)
                state.lastOccupied = os.clock()
                local forbidFire = isDriver or not state.passengerFire
                if forbidFire then
                    occupantHum:UnequipTools()
                    player:SetAttribute("VehicleNoFire", true)
                end
                local conns = {}
                if forbidFire then
                    table.insert(
                        conns,
                        char.ChildAdded:Connect(function(child)
                            if child:IsA("Tool") and player:GetAttribute("VehicleNoFire") then
                                task.defer(function()
                                    if occupantHum.Parent and player:GetAttribute("VehicleNoFire") then
                                        occupantHum:UnequipTools()
                                    end
                                end)
                            end
                        end)
                    )
                end
                table.insert(
                    conns,
                    occupantHum.Died:Connect(function()
                        clearOccupant(player)
                    end)
                )
                occupiedByPlayer[player] = { state = state, seat = seat, conns = conns }
                VehicleService.Client.VehicleStateChanged:Fire(player, model, isDriver and "Driver" or "Passenger")

                if isDriver then
                    state.driver = player
                    state.atHome = false
                    model:SetAttribute("DriverTeam", player:GetAttribute("Team") or state.team)
                    model:SetAttribute("ActivePilot", true)
                    setAnchored(state, false)
                    pcall(function()
                        root:SetNetworkOwner(player)
                    end)
                end
            else
                for p, rec in occupiedByPlayer do
                    if rec.seat == seat then
                        clearOccupant(p)
                        break
                    end
                end
                if isDriver then
                    state.driver = nil
                    model:SetAttribute("ActivePilot", false)
                    if not anyOccupant(state) then
                        state.lastOccupied = os.clock()
                    end
                    pcall(function()
                        root:SetNetworkOwner(nil)
                    end)
                    local lv = root:FindFirstChild("DriveVelocity")
                    local av = root:FindFirstChild("DriveTurn")
                    if lv then
                        lv.VectorVelocity = spec.isAir and Vector3.new(0, -14, 0) or Vector3.zero
                    end
                    if av then
                        av.AngularVelocity = Vector3.zero
                    end
                end
            end
        end)
    end
end

function VehicleService:Clear()
    buildVersion += 1
    for player in occupiedByPlayer do
        clearOccupant(player)
    end
    table.clear(activeEntries)
    if activeFolder then
        activeFolder:Destroy()
        activeFolder = nil
    end
end

function VehicleService:Build(layout, mapFolder)
    self:Clear()
    if not layout or not layout.VehicleSpawns then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "Vehicles"
    folder.Parent = mapFolder
    activeFolder = folder
    local version = buildVersion

    local spawns = layout.VehicleSpawns
    if spawns.Helicopter and spawns.Helicopter.pads then
        for i, pad in spawns.Helicopter.pads do
            self:SpawnEntry({
                kind = "Helicopter",
                name = pad.team .. "_Helicopter_" .. i,
                team = pad.team,
                pos = pad.pos,
                yaw = pad.yaw,
                passengerFire = spawns.Helicopter.passengerFire,
                respawn = spawns.Helicopter.respawn,
                abandonedReset = spawns.Helicopter.abandonedReset,
            }, version)
        end
    end
    if spawns.RHIB and spawns.RHIB.docks then
        for i, dock in spawns.RHIB.docks do
            self:SpawnEntry({
                kind = "RHIB",
                name = dock.team .. "_RHIB_" .. i,
                team = dock.team,
                pos = dock.pos,
                yaw = dock.yaw,
                passengerFire = spawns.RHIB.passengerFire,
                respawn = spawns.RHIB.respawn,
                abandonedReset = spawns.RHIB.abandonedReset,
            }, version)
        end
    end
    if spawns.WaveRunner and spawns.WaveRunner.docks then
        for i, dock in spawns.WaveRunner.docks do
            self:SpawnEntry({
                kind = "WaveRunner",
                name = dock.team .. "_WaveRunner_" .. i,
                team = dock.team,
                pos = dock.pos,
                yaw = dock.yaw,
                accentIndex = ((i - 1) % 2) + 1,
                passengerFire = spawns.WaveRunner.passengerFire,
                respawn = spawns.WaveRunner.respawn,
                abandonedReset = spawns.WaveRunner.abandonedReset,
            }, version)
        end
    end
end

function VehicleService.Client:RequestExit(player)
    local rec = occupiedByPlayer[player]
    if not rec then
        return false
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Sit = false
    end
    clearOccupant(player)
    return true
end

function VehicleService:KnitStart()
    Players.PlayerRemoving:Connect(function(player)
        clearOccupant(player)
    end)

    -- Monitor out-of-bounds vehicles, helicopter auto-settle, and 25s abandoned resets
    task.spawn(function()
        while true do
            task.wait(0.5)
            local MapService = Knit.GetService("MapService")
            local layout = MapService.Layout
            local bounds = layout and layout.Bounds
            local recoveryY = layout and layout.RecoveryY or -25
            local now = os.clock()

            for i = #activeEntries, 1, -1 do
                local state = activeEntries[i]
                if state.destroying or not state.model.Parent or not state.root.Parent then
                    table.remove(activeEntries, i)
                    continue
                end
                local pos = state.root.Position
                if not state.atHome and pos.Y < recoveryY then
                    destroyAndRespawn(state, state.respawn, false)
                    continue
                end
                if bounds then
                    local mn, mx = bounds.min, bounds.max
                    if pos.X < mn[1] or pos.X > mx[1] or pos.Z < mn[3] or pos.Z > mx[3] then
                        destroyAndRespawn(state, state.respawn, false)
                        continue
                    end
                end

                -- Unoccupied helicopter settles softly down onto ground/water
                if state.kind == "Helicopter" and not state.atHome and not state.driver then
                    local lv = state.root:FindFirstChild("DriveVelocity")
                    if lv then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        rayParams.FilterDescendantsInstances = { state.model }
                        local hit = workspace:Raycast(pos, Vector3.new(0, -3.5, 0), rayParams)
                        if hit or pos.Y <= 1.2 then
                            lv.VectorVelocity = Vector3.zero
                        else
                            lv.VectorVelocity = Vector3.new(0, -14, 0)
                        end
                    end
                end

                if
                    not state.atHome
                    and not anyOccupant(state)
                    and (now - state.lastOccupied) >= state.abandonedReset
                then
                    destroyAndRespawn(state, 0.25, false)
                end
            end
        end
    end)
end

return VehicleService
