-- Canonical builder for SciFiFoundry: combines the approved Main Lane upgrades
-- (Thermal Exchange Core, Chamfered Blast Portals, Mid Mezzanine Catwalks, Staggered Cover,
-- Overhead Spine Truss) with the gritty industrial pass via tools/mapkit/IndustrialKit.luau.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Kit = require("./mapkit/IndustrialKit")

local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local Instance = roblox.Instance

local SOURCE_PATH = "assets/environment/source/SciFiFoundry.rbxm"
local MYMAP_PATH = "assets/environment/source/MyMap.rbxm"
local LOBBY_PATH = "assets/environment/source/Lobby.rbxm"

local C = Kit.COLORS
local MV = Kit.VARIANTS

-- Circular Grav-Lift Emitter Pad
local function buildGravLiftVisual(parent, name, x, z, bayLabel, trimKey, glowKey, stencilOffsetZ)
    trimKey = trimKey or "TrimCyan"
    glowKey = glowKey or "CryoGlow"
    local stencilZ = z + (stencilOffsetZ or 8.5)
    local m = Instance.new("Model")
    m.Name = name
    Kit.makeCylinder(m, "HousingOuter", { x, 0.25, z }, 0.5, 11.2, "WallRib", "Metal", true, nil, nil, MV.GunmetalWall)
    Kit.makeCylinder(
        m,
        "HousingBevel",
        { x, 0.45, z },
        0.35,
        9.6,
        "DarkSteel",
        "DiamondPlate",
        true,
        nil,
        nil,
        MV.DiamondTread
    )
    local outerRing = Kit.makeCylinder(m, "OuterGlowRing", { x, 0.56, z }, 0.3, 8.4, trimKey, "Neon", true)
    Kit.makeCylinder(m, "InnerDarkDeck", { x, 0.60, z }, 0.3, 6.6, "Wall", "Metal", true)
    local innerRing = Kit.makeCylinder(m, "InnerGlowRing", { x, 0.64, z }, 0.3, 4.4, glowKey, "Neon", true)
    Kit.makeCylinder(m, "Hub", { x, 0.70, z }, 0.3, 2.2, "WallRib", "Metal", true)
    Kit.makeCylinder(m, "LiftBeam", { x, 7.2, z }, 13.5, 5.2, trimKey, "Neon", true, 0.86)
    Kit.makeCylinder(m, "LiftCoreBeam", { x, 7.2, z }, 13.5, 2.2, glowKey, "Neon", true, 0.78)
    Kit.addLight(outerRing, trimKey, 1.7, 30)

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "GravSparks"
    emitter.Color = roblox.ColorSequence.new(C[trimKey], C.TrimNeutral)
    emitter.LightEmission = 1
    emitter.Size = roblox.NumberSequence.new({
        roblox.NumberSequenceKeypoint.new(0, 0.4),
        roblox.NumberSequenceKeypoint.new(1, 0.05),
    })
    emitter.Transparency = roblox.NumberSequence.new({
        roblox.NumberSequenceKeypoint.new(0, 0.15),
        roblox.NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = roblox.NumberRange.new(0.7, 1.15)
    emitter.Rate = 34
    emitter.Speed = roblox.NumberRange.new(18, 26)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.SpreadAngle = roblox.Vector2.new(8, 8)
    emitter.Parent = innerRing

    local plate = Kit.makePart(
        m,
        "BayStencil",
        { x, 0.09, stencilZ },
        { 10, 0.04, 2.5 },
        nil,
        "FloorSeam",
        "SmoothPlastic",
        true
    )
    plate.Transparency = 1
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Stencil"
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 18
    gui.Parent = plate
    local lbl = Instance.new("TextLabel")
    lbl.Size = roblox.UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.Text = bayLabel
    lbl.TextScaled = true
    lbl.FontFace = roblox.Font.fromEnum(Enum.Font.RobotoMono)
    lbl.TextColor3 = C[trimKey]
    lbl.Parent = gui

    m.Parent = parent
end

-- Steel guardrail segment along X or Z
local function buildRailingX(parent, name, x1, x2, y, z, accentKey)
    local len = math.abs(x2 - x1)
    local cx = (x1 + x2) * 0.5
    local m = Instance.new("Model")
    m.Name = name
    Kit.makePart(m, "TopBar", { cx, y + 3.2, z }, { len, 0.24, 0.24 }, nil, "Cover", "Metal", true)
    Kit.makePart(
        m,
        "MidBar",
        { cx, y + 1.75, z },
        { len, 0.16, 0.16 },
        nil,
        accentKey or "PipeSteel",
        accentKey and "Neon" or "Metal",
        true
    )
    local posts = math.max(2, math.floor(len / 6) + 1)
    for i = 0, posts - 1 do
        local px = x1 + (x2 - x1) * (i / (posts - 1))
        Kit.makePart(m, "Post" .. i, { px, y + 1.65, z }, { 0.28, 3.3, 0.28 }, nil, "WallRib", "Metal", true)
    end
    m.Parent = parent
end

local function buildRailingZ(parent, name, x, y, z1, z2, accentKey)
    local len = math.abs(z2 - z1)
    local cz = (z1 + z2) * 0.5
    local m = Instance.new("Model")
    m.Name = name
    Kit.makePart(m, "TopBar", { x, y + 3.2, cz }, { 0.24, 0.24, len }, nil, "Cover", "Metal", true)
    Kit.makePart(
        m,
        "MidBar",
        { x, y + 1.75, cz },
        { 0.16, 0.16, len },
        nil,
        accentKey or "PipeSteel",
        accentKey and "Neon" or "Metal",
        true
    )
    local posts = math.max(2, math.floor(len / 6) + 1)
    for i = 0, posts - 1 do
        local pz = z1 + (z2 - z1) * (i / (posts - 1))
        Kit.makePart(m, "Post" .. i, { x, y + 1.65, pz }, { 0.28, 3.3, 0.28 }, nil, "WallRib", "Metal", true)
    end
    m.Parent = parent
end

-- Spinning recessed wall exhaust fan + steam vent
local function buildWallFan(parent, name, x, y, z, glowKey)
    local m = Instance.new("Model")
    m.Name = name
    Kit.makePart(m, "FrameTop", { x, y + 4.4, z }, { 9.2, 0.8, 1.6 }, nil, "WallRib", "Metal", true)
    Kit.makePart(m, "FrameBot", { x, y - 4.4, z }, { 9.2, 0.8, 1.6 }, nil, "WallRib", "Metal", true)
    Kit.makePart(m, "FrameL", { x - 4.4, y, z }, { 0.8, 8.8, 1.6 }, nil, "WallRib", "Metal", true)
    Kit.makePart(m, "FrameR", { x + 4.4, y, z }, { 0.8, 8.8, 1.6 }, nil, "WallRib", "Metal", true)
    local backlight = Kit.makePart(
        m,
        "BackGlow",
        { x, y, z - 0.5 },
        { 7.6, 7.6, 0.3 },
        nil,
        glowKey or "CryoGlow",
        "Neon",
        true
    )
    backlight.Transparency = 0.55

    local rotor = Instance.new("Model")
    rotor.Name = "Rotor"
    local hub = Kit.makePart(
        rotor,
        "Hub",
        { x, y, z },
        { 1.6, 1.6, 1.2 },
        nil,
        "DarkSteel",
        "Metal",
        true,
        Enum.PartType.Cylinder
    )
    hub.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(90), 0)
    Kit.makePart(rotor, "BladeA", { x, y, z }, { 7.4, 1.2, 0.25 }, nil, "PipeSteel", "Metal", true)
    Kit.makePart(rotor, "BladeB", { x, y, z }, { 7.4, 1.2, 0.25 }, { 0, 0, 90 }, "PipeSteel", "Metal", true)
    rotor.PrimaryPart = hub
    rotor:SetAttribute("SpinSpeed", 2.8)
    rotor:AddTag("SpinFan")
    rotor.Parent = m

    for _, gy in { -2.4, 0, 2.4 } do
        Kit.makePart(
            m,
            ("Grate_%g"):format(gy),
            { x, y + gy, z + 0.7 },
            { 8.2, 0.35, 0.35 },
            nil,
            "WallRib",
            "Metal",
            true
        )
    end
    m.Parent = parent
end

-- Overhead Traveling Crane (anchored to CeilingGirderZ_±84, clears SpinePipe at Y=32.8)
local function buildOverheadCrane(parent, y, z, accentKey)
    Kit.makePart(
        parent,
        "CraneTrackBeam_" .. math.abs(z),
        { 0, y + 1.8, z },
        { 196, 1.2, 1.8 },
        nil,
        "WallRib",
        "Metal",
        true
    )
    for _, hx in { -84, 84 } do
        local topY = 36.8
        local botY = y + 2.4
        Kit.makePart(
            parent,
            ("CraneHanger_%d_%d"):format(math.abs(z), hx),
            { hx, (topY + botY) * 0.5, z },
            { 1.0, topY - botY, 1.0 },
            nil,
            "WallRib",
            "Metal",
            true
        )
    end
    Kit.makePart(
        parent,
        "CraneTrackTrim_" .. math.abs(z),
        { 0, y + 1.15, z },
        { 196, 0.22, 2.0 },
        nil,
        accentKey,
        "Neon",
        true
    )

    local crane = Instance.new("Model")
    crane.Name = "TravelingCrane_" .. math.abs(z)
    local trolley = Kit.makePart(
        crane,
        "Trolley",
        { 0, y + 0.4, z },
        { 11, 1.8, 4.6 },
        nil,
        "DarkSteel",
        "Metal",
        true,
        nil,
        MV.GunmetalWall
    )
    Kit.makePart(crane, "TrolleyAccent", { 0, y + 0.4, z }, { 11.2, 0.4, 4.8 }, nil, accentKey, "Neon", true)
    Kit.makePart(crane, "CableL", { -3.0, y - 3.2, z }, { 0.25, 6.2, 0.25 }, nil, "PipeSteel", "Metal", true)
    Kit.makePart(crane, "CableR", { 3.0, y - 3.2, z }, { 0.25, 6.2, 0.25 }, nil, "PipeSteel", "Metal", true)
    Kit.makePart(
        crane,
        "CargoPod",
        { 0, y - 7.0, z },
        { 8.8, 3.6, 4.2 },
        nil,
        "DarkSteel",
        "DiamondPlate",
        true,
        nil,
        MV.DiamondTread
    )
    local podLight = Kit.makePart(
        crane,
        "PodBeacon",
        { 0, y - 5.1, z },
        { 1.4, 0.35, 1.4 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
    Kit.addLight(podLight, "OrangeLight", 1.3, 24)
    crane.PrimaryPart = trolley
    crane:SetAttribute("GlideSpan", 46)
    crane:SetAttribute("GlideSpeed", z < 0 and 0.16 or -0.14)
    crane:AddTag("CraneGlide")
    crane.Parent = parent
end

-- Heavy Bulkhead Wall Segment with GunmetalVariant, I-beam pilasters, louvers & upper viewport
local function buildBulkheadSegment(solidParent, decorParent, name, x, z, w, h, d, trimKey, withViewport)
    Kit.makePart(solidParent, name, { x, h * 0.5, z }, { w, h, d }, nil, "Wall", "Metal", false, nil, MV.GunmetalWall)
    local alongX = w >= d
    if alongX then
        Kit.makePart(
            decorParent,
            name .. "_Wainscot",
            { x, 2.2, z },
            { w + 0.2, 4.4, d + 0.5 },
            nil,
            "WallRib",
            "DiamondPlate",
            true
        )
        Kit.makePart(
            decorParent,
            name .. "_Clad",
            { x, h * 0.56, z },
            { math.max(1, w - 2), h * 0.48, d + 0.24 },
            nil,
            "WallPanel",
            "Metal",
            true,
            nil,
            MV.GunmetalWall
        )
        Kit.makePart(
            decorParent,
            name .. "_Cap",
            { x, h - 0.4, z },
            { w + 0.3, 0.9, d + 0.6 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            decorParent,
            name .. "_NeonLow",
            { x, 4.5, z },
            { math.max(1, w - 2), 0.26, d + 0.48 },
            nil,
            trimKey,
            "Neon",
            true
        )
        Kit.makePart(
            decorParent,
            name .. "_NeonHi",
            { x, h - 1.1, z },
            { math.max(1, w - 2), 0.22, d + 0.48 },
            nil,
            trimKey,
            "Neon",
            true
        )
        local nRibs = math.max(2, math.floor(w / 14) + 1)
        for i = 0, nRibs - 1 do
            local rx = (x - w * 0.45) + (w * 0.9) * (i / (nRibs - 1))
            Kit.buildIBeam(decorParent, ("%s_Pilaster_%d"):format(name, i), rx, z, h, 1.8, d + 0.9, "WallRib", true)
        end
        if withViewport then
            local glassKey = (trimKey == "TrimOrange") and "GlassWarm" or "GlassBlue"
            local glass = Kit.makePart(
                decorParent,
                name .. "_Viewport",
                { x, 11.8, z },
                { w * 0.58, 2.4, d + 0.34 },
                nil,
                glassKey,
                "Glass",
                true
            )
            glass.Transparency = 0.38
            Kit.makePart(
                decorParent,
                name .. "_VpTop",
                { x, 13.15, z },
                { w * 0.6, 0.35, d + 0.42 },
                nil,
                "WallRib",
                "Metal",
                true
            )
            Kit.makePart(
                decorParent,
                name .. "_VpBot",
                { x, 10.45, z },
                { w * 0.6, 0.35, d + 0.42 },
                nil,
                "WallRib",
                "Metal",
                true
            )
        end
    else
        Kit.makePart(
            decorParent,
            name .. "_Wainscot",
            { x, 2.2, z },
            { w + 0.5, 4.4, d + 0.2 },
            nil,
            "WallRib",
            "DiamondPlate",
            true,
            nil,
            MV.DiamondTread
        )
        Kit.makePart(
            decorParent,
            name .. "_Clad",
            { x, h * 0.56, z },
            { w + 0.24, h * 0.48, math.max(1, d - 2) },
            nil,
            "WallPanel",
            "Metal",
            true,
            nil,
            MV.GunmetalWall
        )
        Kit.makePart(
            decorParent,
            name .. "_Cap",
            { x, h - 0.4, z },
            { w + 0.6, 0.9, d + 0.3 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            decorParent,
            name .. "_NeonLow",
            { x, 4.5, z },
            { w + 0.48, 0.26, math.max(1, d - 2) },
            nil,
            trimKey,
            "Neon",
            true
        )
        Kit.makePart(
            decorParent,
            name .. "_NeonHi",
            { x, h - 1.1, z },
            { w + 0.48, 0.22, math.max(1, d - 2) },
            nil,
            trimKey,
            "Neon",
            true
        )
        local nRibs = math.max(2, math.floor(d / 14) + 1)
        for i = 0, nRibs - 1 do
            local rz = (z - d * 0.45) + (d * 0.9) * (i / (nRibs - 1))
            Kit.buildIBeam(solidParent, ("%s_Pilaster_%d"):format(name, i), x, rz, h, w + 0.9, 1.8, "WallRib", false)
        end
    end
end

local function buildMirroredBulkhead(solidParent, decorParent, name, x, z, w, h, d, trimKey, withViewport)
    buildBulkheadSegment(solidParent, decorParent, "Red_" .. name, x, z, w, h, d, trimKey, withViewport)
    buildBulkheadSegment(solidParent, decorParent, "Blue_" .. name, -x, z, w, h, d, trimKey, withViewport)
end

-- Hero Thermal Exchange Core Pillar (MidPylon upgrade - flush base trim, brushed steel finish)
local function buildThermalExchangeCore(solidParent, decorParent)
    -- Solid core at exact center (0, 0, 0): 10 x 16 x 8 (well clear of Objective C at z=-18, r=12)
    Kit.makePart(solidParent, "MidPylon", { 0, 8.0, 0 }, { 10, 16, 8 }, nil, "DarkSteel", "Metal", false)
    -- Flush base plate apron (0.24 studs) so movement around center never snags on a tall step
    Kit.makePart(
        decorParent,
        "ThermalCore_BasePlinth",
        { 0, 0.12, 0 },
        { 12.6, 0.24, 10.6 },
        nil,
        "CatwalkSteel",
        "DiamondPlate",
        true
    )
    Kit.makePart(
        decorParent,
        "ThermalCore_MidCollar",
        { 0, 10.6, 0 },
        { 11.8, 1.4, 9.8 },
        nil,
        "WallRib",
        "Metal",
        true
    )
    Kit.makePart(decorParent, "ThermalCore_Cap", { 0, 15.8, 0 }, { 11.4, 1.2, 9.4 }, nil, "WallRib", "Metal", true)
    Kit.makePart(
        decorParent,
        "ThermalCore_CrownShaft",
        { 0, 27.0, 0 },
        { 6.2, 22.0, 5.2 },
        nil,
        "WallRib",
        "Metal",
        true,
        nil,
        MV.GunmetalWall
    )
    Kit.makePart(
        decorParent,
        "ThermalCore_CeilingCollar",
        { 0, 37.3, 0 },
        { 9.6, 1.4, 8.6 },
        nil,
        "WallRib",
        "Metal",
        true
    )
    -- Upper louver banks on East/West sides
    for _, sx in { -1, 1 } do
        for ly = 11.8, 14.2, 0.8 do
            Kit.makePart(
                decorParent,
                ("ThermalCore_Louver_%d_%g"):format(sx, ly),
                { sx * 5.2, ly, 0 },
                { 0.4, 0.35, 5.4 },
                nil,
                "WallRib",
                "Metal",
                true
            )
        end
    end
    -- North Face (-Z): Twin vertical electric CYAN Cryo plasma columns + cyan light pool
    for _, px in { -2.4, 2.4 } do
        Kit.makeCylinder(
            decorParent,
            ("ThermalCore_CyanTube_%g"):format(px),
            { px, 5.8, -4.3 },
            8.6,
            1.35,
            "TrimCyan",
            "Neon",
            false
        )
    end
    local cNode = Kit.makePart(
        decorParent,
        "ThermalCore_CyanNode",
        { 0, 6.0, -5.2 },
        { 0.6, 0.6, 0.6 },
        nil,
        "TrimCyan",
        "Neon",
        true
    )
    Kit.addLight(cNode, "TrimCyan", 2.0, 34, true)
    -- South Face (+Z): Stacked horizontal EMBER ORANGE smelter induction rings + orange light pool
    for _, ry in { 2.4, 3.6, 4.8, 6.0, 7.2, 8.4 } do
        Kit.makePart(
            decorParent,
            ("ThermalCore_OrangeCoil_%g"):format(ry),
            { 0, ry, 4.25 },
            { 6.4, 0.48, 0.7 },
            nil,
            "TrimOrange",
            "Neon",
            true
        )
    end
    local oNode = Kit.makePart(
        decorParent,
        "ThermalCore_OrangeNode",
        { 0, 6.0, 5.2 },
        { 0.6, 0.6, 0.6 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
    Kit.addLight(oNode, "OrangeLight", 2.2, 36, true)
    -- Hazard chevron apron around core base
    Kit.makeHazardStrip(decorParent, "ThermalCore_HazardN", { 0, 0.08, -7.2 }, 15, 1.2, 0, 0.08)
    Kit.makeHazardStrip(decorParent, "ThermalCore_HazardS", { 0, 0.08, 7.2 }, 15, 1.2, 0, 0.08)
end

-- === BUILD SCIFIFOUNDRY ===
local myMap = roblox.deserializeModel(fs.readFile(MYMAP_PATH))[1]
local mmInside = myMap.Geometry.Inside
local mmFirst = mmInside["_First Floor"]
local mmSecond = mmInside["2nd Floor"]
local mmOutdoor = myMap.Geometry._Outdoor
local lobby = roblox.deserializeModel(fs.readFile(LOBBY_PATH))[1]

local TEMPLATES = {
    IntactTube = mmFirst["Tubes and Lab"]:FindFirstChild("Tube"),
    BreachedTube = mmSecond:FindFirstChild("Tube"),
    ServerRackBank = mmFirst:FindFirstChild("Server Rack New"),
    StandingDesk = mmSecond.StandingDesks_2ndFloor:FindFirstChild("Scene"),
    BlackBox = mmFirst:FindFirstChild("Black Box"),
    BlackOrangeBox = mmOutdoor:FindFirstChild("Black and Orange Box"),
    GlossyAngularBox = mmOutdoor:FindFirstChild("Orange and Black Box"),
    ContainmentCanister = lobby.Geometry.Cannister:FindFirstChild("BlueContainmentCanister"),
}

local roots = roblox.deserializeModel(fs.readFile(SOURCE_PATH))
local root = roots[1]

local ground = root:FindFirstChild("Ground")
local floor = ground and ground:FindFirstChild("Floor")
if floor and floor:IsA("BasePart") then
    floor.Size = Vector3.new(256, 1, 256)
    floor.CFrame = CFrame.new(0, -0.5, 0)
    floor.Color = C.FloorSeam
    floor.Material = Enum.Material.Slate
end

local geometry = root:FindFirstChild("Geometry")
for _, child in geometry:GetChildren() do
    child:Destroy()
end

local inside = Instance.new("Folder")
inside.Name = "Inside"
inside.Parent = geometry

local mainPieces = Instance.new("Folder")
mainPieces.Name = "Main Pieces"
mainPieces.Parent = geometry

local cryoArt = Instance.new("Folder")
cryoArt.Name = "CryoBayArt"
cryoArt.Parent = inside

local foundryArt = Instance.new("Folder")
foundryArt.Name = "FoundryFacilityArt"
foundryArt.Parent = inside

-- 1. Enclosure Walls & Solid Y=38.5 Roof
Kit.makePart(mainPieces, "WallN", { 0, 19, -129 }, { 260, 38, 2 }, nil, "Wall", "Metal", false, nil, MV.GunmetalWall)
Kit.makePart(mainPieces, "WallS", { 0, 19, 129 }, { 260, 38, 2 }, nil, "Wall", "Metal", false, nil, MV.GunmetalWall)
Kit.makePart(mainPieces, "WallW", { -129, 19, 0 }, { 2, 38, 260 }, nil, "Wall", "Metal", false, nil, MV.GunmetalWall)
Kit.makePart(mainPieces, "WallE", { 129, 19, 0 }, { 2, 38, 260 }, nil, "Wall", "Metal", false, nil, MV.GunmetalWall)
Kit.makePart(mainPieces, "CeilingDeck", { 0, 38.5, 0 }, { 260, 1, 260 }, nil, "CeilingDeck", "Metal", false)

-- 2. Gantries N (Cyan) and S (Orange) — Steel DiamondPlate decks & ramps (Z=0 centerline kept completely flat & open)
Kit.makePart(mainPieces, "GantryN", { 0, 11, -78 }, { 112, 1, 20 }, nil, "CatwalkSteel", "DiamondPlate", false)
Kit.makePart(mainPieces, "GantryS", { 0, 11, 106 }, { 104, 1, 16 }, nil, "CatwalkSteel", "DiamondPlate", false)
Kit.makeRampMirrored(
    mainPieces,
    "GantryNRamp",
    { -82, 0, -78 },
    { -56, 11.5, -78 },
    16,
    1,
    "CatwalkSteel",
    "DiamondPlate",
    false
)
Kit.addRampSupportMirrored(cryoArt, cryoArt, "GantryNRamp", { -82, 0, -78 }, { -56, 11.5, -78 }, 16, 1, "TrimCyan")
Kit.makeHazardStrip(cryoArt, "Red_GantryNRampHazard", { -84.2, 0.08, -78 }, 16, 2.2, 90, 0.08)
Kit.makeHazardStrip(cryoArt, "Blue_GantryNRampHazard", { 84.2, 0.08, -78 }, 16, 2.2, 90, 0.08)
Kit.makeRampMirrored(
    mainPieces,
    "GantrySRamp",
    { -78, 0, 106 },
    { -52, 11.5, 106 },
    16,
    1,
    "CatwalkSteel",
    "DiamondPlate",
    false
)
Kit.addRampSupportMirrored(
    foundryArt,
    foundryArt,
    "GantrySRamp",
    { -78, 0, 106 },
    { -52, 11.5, 106 },
    16,
    1,
    "TrimOrange"
)
Kit.makeHazardStrip(foundryArt, "Red_GantrySRampHazard", { -80.2, 0.08, 106 }, 16, 2.2, 90, 0.08)
Kit.makeHazardStrip(foundryArt, "Blue_GantrySRampHazard", { 80.2, 0.08, 106 }, 16, 2.2, 90, 0.08)

-- 4. Spawn Bulkhead Partition (|X| = 88): Central Portal + Pier Buttresses + Open Side-Flank Portals
buildMirroredBulkhead(mainPieces, foundryArt, "SpawnScreenN", -88, -12.5, 2.6, 20, 6.5, "TrimCyan", false)
buildMirroredBulkhead(mainPieces, foundryArt, "SpawnScreenS", -88, 12.5, 2.6, 20, 6.5, "TrimOrange", false)
buildMirroredBulkhead(mainPieces, foundryArt, "SpawnScreenCornerN", -88, -29.2, 2.6, 20, 2.4, "TrimCyan", false)
buildMirroredBulkhead(mainPieces, foundryArt, "SpawnScreenCornerS", -88, 29.2, 2.6, 20, 2.4, "TrimOrange", false)
Kit.buildChamferedPortal(
    mainPieces,
    foundryArt,
    "Red_SpawnOverwatchPortal",
    -88,
    0,
    18,
    12,
    20,
    3.0,
    false,
    "TrimNeutral",
    "MAIN LANE // DEPLOY"
)
Kit.buildChamferedPortal(
    mainPieces,
    foundryArt,
    "Blue_SpawnOverwatchPortal",
    88,
    0,
    18,
    12,
    20,
    3.0,
    false,
    "TrimNeutral",
    "MAIN LANE // DEPLOY"
)
Kit.buildChamferedPortal(
    mainPieces,
    cryoArt,
    "Red_SpawnFlankPortalN",
    -88,
    -22,
    12,
    11.5,
    20,
    2.8,
    false,
    "TrimCyan",
    "CRYO FLANK"
)
Kit.buildChamferedPortal(
    mainPieces,
    cryoArt,
    "Blue_SpawnFlankPortalN",
    88,
    -22,
    12,
    11.5,
    20,
    2.8,
    false,
    "TrimCyan",
    "CRYO FLANK"
)
Kit.buildChamferedPortal(
    mainPieces,
    foundryArt,
    "Red_SpawnFlankPortalS",
    -88,
    22,
    12,
    11.5,
    20,
    2.8,
    false,
    "TrimOrange",
    "REACTOR FLANK"
)
Kit.buildChamferedPortal(
    mainPieces,
    foundryArt,
    "Blue_SpawnFlankPortalS",
    88,
    22,
    12,
    11.5,
    20,
    2.8,
    false,
    "TrimOrange",
    "REACTOR FLANK"
)

-- 5. Z = ±32 Bulkhead Room Partitions + CHAMFERED CENTER BLAST PORTALS (Mockup 2)
buildMirroredBulkhead(mainPieces, cryoArt, "CryoBulkheadInner", -54, -32, 76, 18, 3.2, "TrimCyan", true)
buildMirroredBulkhead(mainPieces, cryoArt, "CryoBulkheadEdge", -119, -32, 18, 18, 3.2, "TrimCyan", false)
Kit.buildChamferedPortal(
    mainPieces,
    cryoArt,
    "CryoCenterPortal",
    0,
    -32,
    32,
    13,
    24,
    4.2,
    true,
    "TrimCyan",
    "SECTOR B // CRYO BAY"
)
Kit.buildChamferedPortal(
    mainPieces,
    cryoArt,
    "Red_CryoWingPortal",
    -101,
    -32,
    18,
    12,
    22,
    3.6,
    true,
    "TrimCyan",
    "CRYO WING"
)
Kit.buildChamferedPortal(
    mainPieces,
    cryoArt,
    "Blue_CryoWingPortal",
    101,
    -32,
    18,
    12,
    22,
    3.6,
    true,
    "TrimCyan",
    "CRYO WING"
)

buildMirroredBulkhead(mainPieces, foundryArt, "ReactorBulkheadInner", -54, 32, 76, 18, 3.2, "TrimOrange", true)
buildMirroredBulkhead(mainPieces, foundryArt, "ReactorBulkheadEdge", -119, 32, 18, 18, 3.2, "TrimOrange", false)
Kit.buildChamferedPortal(
    mainPieces,
    foundryArt,
    "ReactorCenterPortal",
    0,
    32,
    32,
    13,
    24,
    4.2,
    true,
    "TrimOrange",
    "SECTOR A // REACTOR BAY"
)
Kit.buildChamferedPortal(
    mainPieces,
    foundryArt,
    "Red_ReactorWingPortal",
    -101,
    32,
    18,
    12,
    22,
    3.6,
    true,
    "TrimOrange",
    "FURNACE WING"
)
Kit.buildChamferedPortal(
    mainPieces,
    foundryArt,
    "Blue_ReactorWingPortal",
    101,
    32,
    18,
    12,
    22,
    3.6,
    true,
    "TrimOrange",
    "FURNACE WING"
)

-- 6. Overwatch Sightline Baffles & Hero Thermal Exchange Core (Mockup 1 & 3)
buildMirroredBulkhead(mainPieces, foundryArt, "MidBaffleN", -54, -17, 2.5, 13, 14, "TrimCyan", false)
buildMirroredBulkhead(mainPieces, foundryArt, "MidBaffleS", -54, 17, 2.5, 13, 14, "TrimOrange", false)
buildThermalExchangeCore(mainPieces, foundryArt)

-- 7. Overhead Center Main-Lane Spine Pipe Truss linking Cryo Portal <-> Thermal Core <-> Reactor Portal
Kit.makePart(foundryArt, "SpineTrussUpperBeam", { 0, 25.0, 0 }, { 4.8, 1.0, 64 }, nil, "WallRib", "Metal", true)
Kit.makePart(foundryArt, "SpineTrussLowerBeam", { 0, 21.4, 0 }, { 4.8, 0.8, 64 }, nil, "WallRib", "Metal", true)
for _, tz in { -24, -12, 12, 24 } do
    Kit.buildXBrace(foundryArt, ("SpineTrussBraceL_%d"):format(tz), { -2.2, 23.2, tz }, 11, 3.2, "Z", 0.35, "WallRib")
    Kit.buildXBrace(foundryArt, ("SpineTrussBraceR_%d"):format(tz), { 2.2, 23.2, tz }, 11, 3.2, "Z", 0.35, "WallRib")
end
-- Glowing Cyan (North half) -> Ember Orange (South half) overhead transfer conduits
for _, px in { -1.5, 1.5 } do
    Kit.makePipeSegment(
        foundryArt,
        ("SpineTrussPipeN_%g"):format(px),
        { px, 23.2, -29.8 },
        { px, 23.2, -2.5 },
        0.9,
        "PipeSteel",
        "Metal",
        8
    )
    Kit.makePipeSegment(
        foundryArt,
        ("SpineTrussPipeS_%g"):format(px),
        { px, 23.2, 2.5 },
        { px, 23.2, 29.8 },
        0.9,
        "AmberDeck",
        "Metal",
        8
    )
    Kit.makePart(
        foundryArt,
        ("SpineTrussGlowN_%g"):format(px),
        { px, 22.5, -16 },
        { 0.25, 0.22, 30 },
        nil,
        "TrimCyan",
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("SpineTrussGlowS_%g"):format(px),
        { px, 22.5, 16 },
        { 0.25, 0.22, 30 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
end
-- Down-facing SpotLight pools under Overhead Spine Truss
for _, sz in { -18, 18 } do
    local spotNode = Kit.makePart(
        foundryArt,
        ("SpineTrussSpot_%d"):format(sz),
        { 0, 20.8, sz },
        { 3.2, 0.35, 2.2 },
        nil,
        sz < 0 and "TrimCyan" or "TrimOrange",
        "Neon",
        true
    )
    Kit.addSpotLight(spotNode, Enum.NormalId.Bottom, sz < 0 and "SkylightWhite" or "SkylightWarm", 2.4, 48, 95, true)
end

-- 8. STAGGERED ANGLED MAIN-LANE TACTICAL COVER (all clear of Objectives C (0,0,-18), B (0,0,-52), A (0,0,48))
Kit.buildBlastShield(inside, foundryArt, "Red_MidShieldN", { -16, 0, -10 }, 22, 8.5, 4.4, 2.2, "TrimCyan")
Kit.buildBlastShield(inside, foundryArt, "Blue_MidShieldN", { 16, 0, -10 }, -22, 8.5, 4.4, 2.2, "TrimCyan")
Kit.buildBlastShield(inside, foundryArt, "Red_MidShieldS", { -17, 0, 13 }, -20, 9.0, 4.6, 2.2, "TrimOrange")
Kit.buildBlastShield(inside, foundryArt, "Blue_MidShieldS", { 17, 0, 13 }, 20, 9.0, 4.6, 2.2, "TrimOrange")
Kit.buildBlastShield(inside, foundryArt, "Red_MidObjCKnee", { -25, 0, -18 }, 90, 7.0, 3.0, 2.8, "TrimCyan")
Kit.buildBlastShield(inside, foundryArt, "Blue_MidObjCKnee", { 25, 0, -18 }, -90, 7.0, 3.0, 2.8, "TrimCyan")
Kit.buildBlastShield(inside, cryoArt, "Red_CryoLaneShield", { -17, 0, -50 }, -18, 8.0, 4.2, 2.2, "TrimCyan")
Kit.buildBlastShield(inside, cryoArt, "Blue_CryoLaneShield", { 17, 0, -50 }, 18, 8.0, 4.2, 2.2, "TrimCyan")
Kit.buildBlastShield(inside, foundryArt, "Red_ReactorLaneShield", { -17, 0, 46 }, 18, 8.0, 4.2, 2.2, "TrimOrange")
Kit.buildBlastShield(inside, foundryArt, "Blue_ReactorLaneShield", { 17, 0, 46 }, -18, 8.0, 4.2, 2.2, "TrimOrange")

-- 9. Reactor Core Forge Assembly (flush floor apron so movement around Objective A never trips on a step)
Kit.makePart(
    foundryArt,
    "ReactorPad",
    { 0, 0.06, 76 },
    { 34, 0.12, 30 },
    nil,
    "AmberDeck",
    "DiamondPlate",
    true,
    nil,
    MV.ForgeSoot
)
Kit.makePart(foundryArt, "ReactorPadOrangeRim", { 0, 0.13, 76 }, { 34.3, 0.12, 30.3 }, nil, "TrimOrange", "Neon", true)
Kit.makePart(mainPieces, "ReactorCore", { 0, 6.1, 76 }, { 11, 12, 11 }, nil, "DarkSteel", "Metal", false)
Kit.makePart(
    foundryArt,
    "ReactorCoreBaseCollar",
    { 0, 0.65, 76 },
    { 13.4, 1.1, 13.4 },
    nil,
    "CatwalkSteel",
    "DiamondPlate",
    false
)
Kit.makePart(
    foundryArt,
    "ReactorCoreTopCollar",
    { 0, 11.7, 76 },
    { 13.0, 0.9, 13.0 },
    nil,
    "CatwalkSteel",
    "DiamondPlate",
    false
)
local rcGlow = Kit.makePart(
    foundryArt,
    "ReactorCoreRing",
    { 0, 6.1, 76 },
    { 11.4, 1.1, 11.4 },
    nil,
    "TrimOrange",
    "Neon",
    false
)
Kit.addLight(rcGlow, "OrangeLight", 2.3, 44, true)
for _, bPos in { { -5.8, -5.8 }, { 5.8, -5.8 }, { -5.8, 5.8 }, { 5.8, 5.8 } } do
    Kit.makePart(
        foundryArt,
        ("ReactorFin_%d_%d"):format(bPos[1], bPos[2]),
        { bPos[1], 6.1, 76 + bPos[2] },
        { 2.0, 11.6, 2.0 },
        nil,
        "WallRib",
        "DiamondPlate",
        false
    )
    Kit.makePart(
        foundryArt,
        ("ReactorCoil_%d_%d"):format(bPos[1], bPos[2]),
        { bPos[1] * 0.85, 6.1, 76 + bPos[2] * 0.85 },
        { 0.45, 10.6, 0.45 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
end
Kit.makeHazardStrip(foundryArt, "ReactorPadHazardN", { 0, 0.08, 60.2 }, 32, 1.6, 0, 0.08)
Kit.makeHazardStrip(foundryArt, "ReactorPadHazardS", { 0, 0.08, 91.8 }, 32, 1.6, 0, 0.08)

buildMirroredBulkhead(mainPieces, cryoArt, "CryoWingPillar", -84, -52, 10, 16, 10, "TrimCyan", false)
buildMirroredBulkhead(mainPieces, foundryArt, "FurnaceWingPillar", -84, 52, 10, 16, 10, "TrimOrange", false)
buildMirroredBulkhead(mainPieces, foundryArt, "ReactorSideShield", -26, 74, 3.0, 13, 18, "TrimOrange", false)

-- Sleek industrial blast cover flanking the reactor floor (replacing oversized plain cubes)
Kit.buildBlastShield(inside, foundryArt, "Red_ReactorSlagShield", { -38, 0, 82 }, 32, 7.2, 3.8, 2.0, "TrimOrange")
Kit.buildBlastShield(inside, foundryArt, "Blue_ReactorSlagShield", { 38, 0, 82 }, -32, 7.2, 3.8, 2.0, "TrimOrange")
Kit.buildBlastShield(inside, foundryArt, "Red_ReactorSideCover", { -48, 0, 68 }, -18, 5.4, 2.8, 1.6, "TrimOrange")
Kit.buildBlastShield(inside, foundryArt, "Blue_ReactorSideCover", { 48, 0, 68 }, 18, 5.4, 2.8, 1.6, "TrimOrange")

-- 10. GRITTY INDUSTRIAL FLOOR (Continuous Mid Slab + Octagonal Core Inlay + Welded Patches + Oil Slicks + Grates)
for ix = -4, 3 do
    local cx = (ix + 0.5) * 30
    for iz = -4, 3 do
        local cz = (iz + 0.5) * 30
        local isMid = (iz == -1 or iz == 0)
        local alt = ((ix + iz) % 2) == 0
        local south = cz > 0
        local colorKey = isMid and "FloorDark"
            or (south and (alt and "FloorSouthA" or "FloorSouthB") or (alt and "FloorDark" or "FloorMid"))
        local mat = isMid and "Concrete"
            or (south and (alt and "Basalt" or "Concrete") or (alt and "Asphalt" or "Concrete"))
        local mv = isMid and MV.ConcreteFloor
            or (south and (alt and MV.ForgeSoot or MV.ConcreteFloor) or MV.ConcreteFloor)
        local tileSpan = isMid and 30.0 or 29.5
        Kit.makePart(
            foundryArt,
            ("DeckTile_%d_%d"):format(ix, iz),
            { cx, 0.025, cz },
            { tileSpan, 0.05, tileSpan },
            nil,
            colorKey,
            mat,
            true,
            nil,
            mv
        )
    end
end

-- Octagonal DiamondPlate Core Floor Inlay & Center Portal Threshold Aprons
Kit.makePart(
    foundryArt,
    "MidPylonOctagonTrim",
    { 0, 0.036, 0 },
    { 25.4, 0.04, 25.4 },
    { 0, 45, 0 },
    "FloorSeam",
    "Metal",
    true
)
Kit.makePart(
    foundryArt,
    "MidPylonOctagon",
    { 0, 0.042, 0 },
    { 23.8, 0.045, 23.8 },
    { 0, 45, 0 },
    "CatwalkSteel",
    "DiamondPlate",
    true,
    nil,
    MV.DiamondTread
)
Kit.makePart(
    cryoArt,
    "CryoPortalApron",
    { 0, 0.045, -32 },
    { 34, 0.05, 10 },
    nil,
    "Bridge",
    "DiamondPlate",
    true,
    nil,
    MV.DiamondTread
)
Kit.makePart(
    foundryArt,
    "ReactorPortalApron",
    { 0, 0.045, 32 },
    { 34, 0.05, 10 },
    nil,
    "Bridge",
    "DiamondPlate",
    true,
    nil,
    MV.DiamondTread
)

-- Heavy DiamondPlate Main Spine Catwalks + Illuminated Edge Rails
Kit.makePart(
    foundryArt,
    "CenterSpineCatwalk",
    { 0, 0.04, 0 },
    { 16, 0.06, 248 },
    nil,
    "CatwalkSteel",
    "DiamondPlate",
    true
)
Kit.makePart(foundryArt, "CenterSpineEdgeCyan", { -8.2, 0.05, -62 }, { 0.35, 0.06, 120 }, nil, "TrimCyan", "Neon", true)
Kit.makePart(foundryArt, "CenterSpineEdgeCyanB", { 8.2, 0.05, -62 }, { 0.35, 0.06, 120 }, nil, "TrimCyan", "Neon", true)
Kit.makePart(
    foundryArt,
    "CenterSpineEdgeOrange",
    { -8.2, 0.05, 62 },
    { 0.35, 0.06, 120 },
    nil,
    "TrimOrange",
    "Neon",
    true
)
Kit.makePart(
    foundryArt,
    "CenterSpineEdgeOrangeB",
    { 8.2, 0.05, 62 },
    { 0.35, 0.06, 120 },
    nil,
    "TrimOrange",
    "Neon",
    true
)
Kit.makePart(
    foundryArt,
    "MidCrossCatwalk",
    { 0, 0.045, 0 },
    { 220, 0.06, 14 },
    nil,
    "CatwalkSteel",
    "DiamondPlate",
    true
)

-- Grate Trenches + Glowing Plasma Wells + Border Hazard Strips
for _, tz in { -60, -98, 56, 94 } do
    local glowColor = tz < 0 and "TrimCyan" or "TrimOrange"
    Kit.makePart(
        foundryArt,
        ("GrateRecess_%d"):format(tz),
        { 0, 0.02, tz },
        { 160, 0.04, 3.8 },
        nil,
        "WallRib",
        "Metal",
        true
    )
    Kit.makePart(
        foundryArt,
        ("GrateGlow_%d"):format(tz),
        { 0, 0.045, tz },
        { 158, 0.02, 2.2 },
        nil,
        glowColor,
        "Neon",
        true
    ).Transparency =
        0.22
    for gx = -78, 78, 3 do
        Kit.makePart(
            foundryArt,
            ("GrateBar_%d_%d"):format(tz, gx),
            { gx, 0.065, tz },
            { 1.1, 0.04, 3.4 },
            nil,
            "WallRib",
            "CorrodedMetal",
            true
        )
    end
end

-- Welded Steel Repair Patches & Oil/Coolant Puddles (cosmetic asymmetric grit!)
local patchCoords = {
    { -12, -40, 8, 5, 6 },
    { 14, -14, 7, 4, -8 },
    { -9, 18, 9, 5, 4 },
    { 18, 42, 7, 5, -5 },
    { -28, -76, 8, 6, 11 },
    { 32, 68, 8, 5, -9 },
    { -58, -12, 6, 7, 7 },
    { 56, 14, 7, 5, -6 },
    { -4, -86, 9, 4, 3 },
    { 6, 88, 8, 5, -4 },
    { -72, 40, 6, 5, 9 },
    { 74, -44, 6, 6, -12 },
    { -48, -94, 7, 4, 14 },
    { 48, -94, 7, 4, -14 },
    { -62, 82, 7, 5, -11 },
    { 62, 82, 7, 5, 11 },
}
for i, pc in patchCoords do
    Kit.makePatchPlate(foundryArt, "RepairPatch_" .. i, pc[1], pc[2], pc[3], pc[4], pc[5])
end
for i, oc in
    {
        { -6, -24, 5.2 },
        { 9, 22, 6.0 },
        { -14, 64, 7.5 },
        { 18, 70, 6.4 },
        { -22, -92, 5.0 },
        { 24, -108, 4.8 },
        { -42, -100, 5.4 },
        { 54, -99, 4.8 },
        { -56, 79, 5.6 },
        { 57, 68, 5.0 },
    }
do
    Kit.makeOilSlick(foundryArt, "OilSlick_" .. i, oc[1], oc[2], oc[3])
end

-- Heated ReactorPad Side Grate Channels (recessed orange plasma heat vents flanking ReactorPad)
for _, sg in { { tag = "W", x = -22.5 }, { tag = "E", x = 22.5 } } do
    Kit.makePart(
        foundryArt,
        "ReactorSideGrateRecess_" .. sg.tag,
        { sg.x, 0.02, 76 },
        { 4.6, 0.04, 26 },
        nil,
        "WallRib",
        "Metal",
        true
    )
    Kit.makePart(
        foundryArt,
        "ReactorSideGrateGlow_" .. sg.tag,
        { sg.x, 0.045, 76 },
        { 2.8, 0.02, 24 },
        nil,
        "TrimOrange",
        "Neon",
        true
    ).Transparency =
        0.18
    for gz = 64, 88, 3 do
        Kit.makePart(
            foundryArt,
            ("ReactorSideGrateBar_%s_%d"):format(sg.tag, gz),
            { sg.x, 0.065, gz },
            { 4.2, 0.04, 1.0 },
            nil,
            "WallRib",
            "CorrodedMetal",
            true
        )
    end
end

-- Rising Forge Ember Plumes in Reactor grates & Core + Pressurized Overhead Steam Vents
Kit.buildEmberPlume(foundryArt, "ReactorEmbers_CoreW", { -9, 0.2, 76 })
Kit.buildEmberPlume(foundryArt, "ReactorEmbers_CoreE", { 9, 0.2, 76 })
Kit.buildEmberPlume(foundryArt, "ReactorEmbers_ApronW", { -14, 0.25, 89.5 })
Kit.buildEmberPlume(foundryArt, "ReactorEmbers_ApronE", { 14, 0.25, 89.5 })
Kit.buildEmberPlume(foundryArt, "ReactorEmbers_Grate", { 0, 0.1, 56 })
Kit.buildSteamVent(cryoArt, "CryoPipeSteam_W", { -56, 31.2, -52 }, Enum.NormalId.Bottom, "CryoSpill")
Kit.buildSteamVent(cryoArt, "CryoPipeSteam_E", { 56, 31.2, -52 }, Enum.NormalId.Bottom, "CryoSpill")
Kit.buildSteamVent(foundryArt, "ReactorPipeSteam_W", { -56, 31.2, 52 }, Enum.NormalId.Bottom, "TrimNeutral")
Kit.buildSteamVent(foundryArt, "ReactorPipeSteam_E", { 56, 31.2, 52 }, Enum.NormalId.Bottom, "TrimNeutral")

-- 11. CEILING TRUSSES, POOL LIGHTING, FLICKERING FAULT LIGHTS & CLAMPED PIPE/CABLE RUNS
for _, tz in { -108, -72, -36, 0, 36, 72, 108 } do
    Kit.makePart(
        foundryArt,
        ("CeilingTrussX_%d"):format(tz),
        { 0, 36.2, tz },
        { 256, 3.6, 2.4 },
        nil,
        "WallRib",
        "Metal",
        true,
        nil,
        MV.GunmetalWall
    )
    local tGlow = tz > 0 and "TrimOrange" or (tz < 0 and "TrimCyan" or "TrimNeutral")
    Kit.makePart(
        foundryArt,
        ("CeilingTrussNeon_%d"):format(tz),
        { 0, 34.3, tz },
        { 220, 0.18, 0.35 },
        nil,
        tGlow,
        "Neon",
        true
    )
    -- Draped industrial cables hanging from ceiling trusses
    Kit.makeDrapedCable(
        foundryArt,
        ("TrussCableW_%d"):format(tz),
        { -84, 34.4, tz },
        { -28, 34.4, tz },
        2.6,
        6,
        0.32,
        "CableBlack"
    )
    Kit.makeDrapedCable(
        foundryArt,
        ("TrussCableE_%d"):format(tz),
        { 28, 34.4, tz },
        { 84, 34.4, tz },
        2.6,
        6,
        0.32,
        "CableBlack"
    )
end
for _, gx in { -84, -28, 28, 84 } do
    Kit.makePart(
        foundryArt,
        ("CeilingGirderZ_%d"):format(gx),
        { gx, 36.8, 0 },
        { 2.2, 2.4, 256 },
        nil,
        "WallRib",
        "Metal",
        true
    )
end

-- Upper-Room Cross-Bay Overhead Box Trusses (Y=29..33.4, clears TravelingCranes at Z=-98 and Z=56)
for _, cz in { -58, 92 } do
    local artParent = cz < 0 and cryoArt or foundryArt
    local accent = cz < 0 and "TrimCyan" or "TrimOrange"
    local tag = cz < 0 and "CryoCrossTruss" or "ReactorCrossTruss"
    Kit.makePart(artParent, tag .. "_TopChord", { 0, 33.4, cz }, { 168, 0.9, 1.4 }, nil, "WallRib", "Metal", true)
    Kit.makePart(artParent, tag .. "_BotChord", { 0, 29.0, cz }, { 168, 0.9, 1.4 }, nil, "WallRib", "Metal", true)
    Kit.makePart(artParent, tag .. "_Accent", { 0, 28.45, cz }, { 150, 0.16, 0.28 }, nil, accent, "Neon", true)
    for _, px in { -84, -60, -36, -12, 12, 36, 60, 84 } do
        Kit.makePart(
            artParent,
            ("%s_Strut_%d"):format(tag, px),
            { px, 31.2, cz },
            { 0.75, 4.4, 1.1 },
            nil,
            "WallRib",
            "Metal",
            true
        )
    end
    for _, bx in { -72, -48, -24, 0, 24, 48, 72 } do
        Kit.buildXBrace(artParent, ("%s_Bay_%d"):format(tag, bx), { bx, 31.2, cz }, 24, 4.2, "X", 0.5, "WallRib")
    end
end

-- Overhead Side-Wall Rectangular HVAC Ductwork (X=±124.2, Y=29.5 across WallRib intervals)
for _, side in
    { { tag = "WestWallDuct", x = -124.2, faceOffset = 1.65 }, { tag = "EastWallDuct", x = 124.2, faceOffset = -1.65 } }
do
    for _, dz in { -90, -54, -18, 18, 54, 90 } do
        local artParent = dz < 0 and cryoArt or foundryArt
        Kit.makePart(
            artParent,
            ("%s_%d"):format(side.tag, dz),
            { side.x, 29.5, dz },
            { 3.2, 3.6, 31.0 },
            nil,
            "PipeSteel",
            "Metal",
            true
        )
        Kit.makePart(
            artParent,
            ("%s_CollarA_%d"):format(side.tag, dz),
            { side.x, 29.5, dz - 10 },
            { 3.55, 3.95, 0.7 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            artParent,
            ("%s_CollarB_%d"):format(side.tag, dz),
            { side.x, 29.5, dz + 10 },
            { 3.55, 3.95, 0.7 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            artParent,
            ("%s_Louver_%d"):format(side.tag, dz),
            { side.x + side.faceOffset, 29.5, dz },
            { 0.16, 2.2, 8.5 },
            nil,
            "WallRib",
            "CorrodedMetal",
            true
        )
    end
end

-- Vertical Steel Gusset Columns tying Spawn Bulkhead headers (|X|=88, Y=20) to CeilingGirderZ_±84
for _, sx in { -88, 88 } do
    local prefix = sx < 0 and "Red_" or "Blue_"
    local gxTie = sx < 0 and -86 or 86
    for _, pz in { -29.2, -12.5, 12.5, 29.2 } do
        local artParent = pz < 0 and cryoArt or foundryArt
        Kit.makePart(
            artParent,
            ("%sSpawnBulkheadCol_%d"):format(prefix, math.floor(pz * 10)),
            { sx, 28.2, pz },
            { 1.8, 16.5, 1.8 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            artParent,
            ("%sSpawnBulkheadTie_%d"):format(prefix, math.floor(pz * 10)),
            { gxTie, 35.6, pz },
            { 5.8, 1.4, 1.6 },
            nil,
            "WallRib",
            "Metal",
            true
        )
    end
end

-- Focused Pool Skylight Grid (covers North Cryo, Mid, South Reactor rear bay Z=114, and Spawn Bays |X|=108)
local lightRowsZ = { -110, -78, -46, -14, 16, 52, 86, 114 }
local lightColsX = { -76, -26, 26, 76 }
for rIdx, lz in lightRowsZ do
    local isSouth = lz > 24
    local lightColorKey = isSouth and "SkylightWarm" or "SkylightWhite"
    local ptColor = isSouth and Color3.fromRGB(255, 206, 168) or Color3.fromRGB(205, 228, 255)
    for cIdx, lx in lightColsX do
        Kit.makePart(
            foundryArt,
            ("SkylightFrame_%d_%d"):format(lx, lz),
            { lx, 37.6, lz },
            { 26, 0.7, 14 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        local panel = Kit.makePart(
            foundryArt,
            ("SkylightPanel_%d_%d"):format(lx, lz),
            { lx, 37.25, lz },
            { 23, 0.35, 11 },
            nil,
            lightColorKey,
            "Neon",
            true
        )
        local pt = Kit.addLight(panel, ptColor, 1.15, 64, false)
        -- Two outer wing fixtures gently flicker for industrial character
        if (rIdx == 4 and cIdx == 1) or (rIdx == 5 and cIdx == 4) then
            pt:AddTag("FlickerLight")
        end
    end
end
-- Dedicated Spawn Bay & Outer Wing Skylights (SpawnScreen bulkheads at |X|=88 otherwise shadow |X|>95)
for _, sx in { -108, 108 } do
    for _, sz in { -84, -36, 0, 36, 84 } do
        local isSouth = sz > 16
        local lightColorKey = isSouth and "SkylightWarm" or "SkylightWhite"
        local ptColor = isSouth and Color3.fromRGB(255, 210, 175) or Color3.fromRGB(205, 228, 255)
        Kit.makePart(
            foundryArt,
            ("SpawnSkylightFrame_%d_%d"):format(sx, sz),
            { sx, 37.6, sz },
            { 16, 0.7, 16 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        local panel = Kit.makePart(
            foundryArt,
            ("SpawnSkylightPanel_%d_%d"):format(sx, sz),
            { sx, 37.25, sz },
            { 13, 0.35, 13 },
            nil,
            lightColorKey,
            "Neon",
            true
        )
        Kit.addLight(panel, ptColor, 1.25, 62, false)
    end
end

-- Overhead Clamped Coolant & Thermal Spine Pipes
for _, px in { -56, 56 } do
    Kit.makePipeSegment(
        foundryArt,
        ("SpinePipeN_%d"):format(px),
        { px, 32.8, -124 },
        { px, 32.8, -4 },
        2.6,
        "PipeSteel",
        "Metal",
        20
    )
    Kit.makePipeSegment(
        foundryArt,
        ("SpinePipeS_%d"):format(px),
        { px, 32.8, 4 },
        { px, 32.8, 124 },
        2.6,
        "AmberDeck",
        "Metal",
        20
    )
    Kit.makePart(
        foundryArt,
        ("SpinePipeGlowN_%d"):format(px),
        { px, 31.3, -64 },
        { 0.35, 0.22, 116 },
        nil,
        "TrimCyan",
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("SpinePipeGlowS_%d"):format(px),
        { px, 31.3, 64 },
        { 0.35, 0.22, 116 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
end

-- Perimeter Walls: I-Beam Ribs, Gunmetal Cladding, DiamondPlate Wainscoting & Neon Slits
for _, rx in { -108, -72, -36, 0, 36, 72, 108 } do
    Kit.buildIBeam(foundryArt, ("WallRibN_%d"):format(rx), rx, -127.4, 38, 2.4, 1.8, "WallRib", false)
    Kit.buildIBeam(foundryArt, ("WallRibS_%d"):format(rx), rx, 127.4, 38, 2.4, 1.8, "WallRib", false)
end
for _, rz in { -108, -72, -36, 0, 36, 72, 108 } do
    Kit.buildIBeam(foundryArt, ("WallRibW_%d"):format(rz), -127.4, rz, 38, 1.8, 2.4, "WallRib", false)
    Kit.buildIBeam(foundryArt, ("WallRibE_%d"):format(rz), 127.4, rz, 38, 1.8, 2.4, "WallRib", false)
end
for _, px in { -90, -54, -18, 18, 54, 90 } do
    Kit.makePart(
        foundryArt,
        ("WallCladN_%d"):format(px),
        { px, 18, -127.75 },
        { 30, 22, 0.45 },
        nil,
        "WallPanel",
        "Metal",
        true,
        nil,
        MV.GunmetalWall
    )
    Kit.makePart(
        foundryArt,
        ("WallCladS_%d"):format(px),
        { px, 18, 127.75 },
        { 30, 22, 0.45 },
        nil,
        "WallPanel",
        "Metal",
        true,
        nil,
        MV.GunmetalWall
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitN_%d"):format(px),
        { px, 27.5, -127.25 },
        { 22, 0.42, 0.3 },
        nil,
        "TrimCyan",
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitNLow_%d"):format(px),
        { px, 5.0, -127.25 },
        { 22, 0.32, 0.3 },
        nil,
        "TrimCyan",
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitS_%d"):format(px),
        { px, 27.5, 127.25 },
        { 22, 0.42, 0.3 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitSLow_%d"):format(px),
        { px, 5.0, 127.25 },
        { 22, 0.32, 0.3 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
end
for _, pz in { -90, -54, -18, 18, 54, 90 } do
    local accent = pz > 0 and "TrimOrange" or "TrimCyan"
    Kit.makePart(
        foundryArt,
        ("WallCladW_%d"):format(pz),
        { -127.75, 18, pz },
        { 0.45, 22, 30 },
        nil,
        "WallPanel",
        "Metal",
        true,
        nil,
        MV.GunmetalWall
    )
    Kit.makePart(
        foundryArt,
        ("WallCladE_%d"):format(pz),
        { 127.75, 18, pz },
        { 0.45, 22, 30 },
        nil,
        "WallPanel",
        "Metal",
        true,
        nil,
        MV.GunmetalWall
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitW_%d"):format(pz),
        { -127.25, 27.5, pz },
        { 0.3, 0.42, 22 },
        nil,
        accent,
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitWLow_%d"):format(pz),
        { -127.25, 5.0, pz },
        { 0.3, 0.32, 22 },
        nil,
        accent,
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitE_%d"):format(pz),
        { 127.25, 27.5, pz },
        { 0.3, 0.42, 22 },
        nil,
        accent,
        "Neon",
        true
    )
    Kit.makePart(
        foundryArt,
        ("WallSlitELow_%d"):format(pz),
        { 127.25, 5.0, pz },
        { 0.3, 0.32, 22 },
        nil,
        accent,
        "Neon",
        true
    )
end
Kit.makePart(foundryArt, "WainscotN", { 0, 2.2, -127.7 }, { 252, 4.4, 0.6 }, nil, "WallRib", "DiamondPlate", false)
Kit.makePart(foundryArt, "WainscotS", { 0, 2.2, 127.7 }, { 252, 4.4, 0.6 }, nil, "WallRib", "DiamondPlate", false)
Kit.makePart(foundryArt, "WainscotW", { -127.7, 2.2, 0 }, { 0.6, 4.4, 252 }, nil, "WallRib", "DiamondPlate", false)
Kit.makePart(foundryArt, "WainscotE", { 127.7, 2.2, 0 }, { 0.6, 4.4, 252 }, nil, "WallRib", "DiamondPlate", false)

-- 12. Grav-Lifts, Cryo Tubes, Clamped Wall Manifold Pipes & Plinth-Mounted PBR Assets
buildGravLiftVisual(cryoArt, "Red_GravLiftEmitter", -50, -46, "GRAV-LIFT // 01", "TrimCyan", "CryoGlow", 8.5)
buildGravLiftVisual(cryoArt, "Blue_GravLiftEmitter", 50, -46, "GRAV-LIFT // 02", "TrimCyan", "CryoGlow", 8.5)
buildGravLiftVisual(foundryArt, "Red_ReactorLiftEmitter", -52, 85, "GRAV-LIFT // 03", "TrimOrange", "OrangeLight", -8.5)
buildGravLiftVisual(foundryArt, "Blue_ReactorLiftEmitter", 52, 85, "GRAV-LIFT // 04", "TrimOrange", "OrangeLight", -8.5)

-- Power/coolant conduits routed cleanly along North Cryo back wall (zero floor tripwires in combat lane)
Kit.makePipeSegment(
    cryoArt,
    "PowerCableRunX",
    { -78, 0.30, -125.8 },
    { 78, 0.30, -125.8 },
    0.5,
    "CableBlack",
    "Rubber",
    22
)
Kit.makePipeSegment(
    cryoArt,
    "PowerCableRunX2",
    { -78, 0.30, -126.5 },
    { 78, 0.30, -126.5 },
    0.35,
    "DarkSteel",
    "Metal",
    22
)
for _, sx in { -28, -13, 13, 28 } do
    Kit.makePipeSegment(
        cryoArt,
        ("CryoTubeFeed_%d"):format(sx),
        { sx, 0.30, -125.8 },
        { sx, 0.30, -124.2 },
        0.42,
        "DarkSteel",
        "Metal",
        0
    )
end

local tubeSlots = {
    { name = "CryoTube_1", x = -28, breached = false },
    { name = "CryoTube_2", x = -13, breached = false },
    { name = "CryoTube_3_Breached", x = 13, breached = true },
    { name = "CryoTube_4", x = 28, breached = false },
}

for _, slot in tubeSlots do
    Kit.makePart(
        cryoArt,
        slot.name .. "_Plinth",
        { slot.x, 0.20, -121.5 },
        { 7.2, 0.40, 5.6 },
        nil,
        "CatwalkSteel",
        "DiamondPlate",
        false
    )
    Kit.makePart(
        cryoArt,
        slot.name .. "_Trim",
        { slot.x, 0.42, -118.75 },
        { 7.4, 0.14, 0.3 },
        nil,
        slot.breached and "FaultRed" or "TrimCyan",
        "Neon",
        true
    )

    if slot.breached then
        local tube =
            Kit.placeAssetClone(TEMPLATES.BreachedTube, cryoArt, slot.name, { slot.x, 0.40, -121.5 }, 0, 0.68, false)
        local strobePart = Kit.makePart(
            tube,
            "FaultStrobeNode",
            { slot.x, 9.2, -119.5 },
            { 0.9, 0.6, 0.9 },
            nil,
            "FaultRed",
            "Neon",
            true
        )
        local strobe = Kit.addLight(strobePart, "FaultRed", 2.0, 32)
        strobe:AddTag("FlickerLight")
        Kit.buildSteamVent(tube, "BreachMistVent", { slot.x, 3.8, -118.4 }, Enum.NormalId.Front, "CryoSpill")
        Kit.makeCylinder(
            cryoArt,
            "BreachIceSheen1",
            { slot.x + 0.5, 0.09, -115.0 },
            0.06,
            9.6,
            "CryoSpill",
            "Ice",
            true,
            0.28
        )
        Kit.makeCylinder(
            cryoArt,
            "BreachIceSheen2",
            { slot.x - 2.4, 0.09, -112.0 },
            0.06,
            5.8,
            "CryoSpill",
            "Ice",
            true,
            0.36
        )
    else
        local tube =
            Kit.placeAssetClone(TEMPLATES.IntactTube, cryoArt, slot.name, { slot.x, 0.40, -121.5 }, 0, 0.68, false)
        local glowNode = Kit.makePart(
            tube,
            "TubeGlowLight",
            { slot.x, 7.4, -118.0 },
            { 0.4, 0.4, 0.4 },
            nil,
            "CryoGlow",
            "SmoothPlastic",
            true
        )
        glowNode.Transparency = 1
        Kit.addLight(glowNode, Color3.fromRGB(0, 196, 255), 0.75, 22)
    end
end

-- Grounded Steel DiamondPlate Plinths for resized curated PBR MeshParts (MapDecor/SciFiFoundry)
-- Data-center ServerRackBanks removed per review; all hero props proportioned to player height.
local function makeHeroPlinth(parent, name, x, z, yawDeg, plW, plD, trimKey)
    Kit.makePart(
        parent,
        name .. "_Plinth",
        { x, 0.16, z },
        { plW, 0.32, plD },
        { 0, yawDeg, 0 },
        "CatwalkSteel",
        "DiamondPlate",
        false
    )
    Kit.makePart(
        parent,
        name .. "_PlinthLip",
        { x, 0.30, z },
        { plW + 0.16, 0.08, plD + 0.16 },
        { 0, yawDeg, 0 },
        trimKey,
        "Neon",
        true
    )
end

makeHeroPlinth(cryoArt, "Red_CryoTelemetryPanel", -78, -113, 122, 3.0, 2.6, "TrimCyan")
makeHeroPlinth(cryoArt, "Red_CryoTubeConsole", -42, -118, 12, 3.0, 2.6, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_CryoTubeConsole", 42, -118, -12, 3.0, 2.6, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_CryoTelemetryPanel", 78, -113, -122, 3.0, 2.6, "TrimCyan")
makeHeroPlinth(cryoArt, "Red_PortalControl", -24, -26.5, -20, 3.0, 2.6, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_PortalControl", 24, -26.5, 20, 3.0, 2.6, "TrimCyan")

makeHeroPlinth(cryoArt, "Red_CryoContainer", -24.5, -55.5, 90, 4.4, 4.4, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_CryoContainer", 24.5, -55.5, -90, 4.4, 4.4, "TrimCyan")
makeHeroPlinth(cryoArt, "Red_CryoGenerator", -48, -104, 0, 9.8, 5.4, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_CryoGenerator", 48, -104, 0, 9.8, 5.4, "TrimCyan")
makeHeroPlinth(cryoArt, "Red_CryoCornerContainer", -66, -116, -25, 4.4, 4.4, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_CryoCornerContainer", 66, -116, 25, 4.4, 4.4, "TrimCyan")
makeHeroPlinth(cryoArt, "Red_CryoChamber", -64, -56, 20, 4.2, 4.2, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_CryoChamber", 64, -56, -20, 4.2, 4.2, "TrimCyan")
makeHeroPlinth(cryoArt, "Red_WingChamber", -106, -58, 0, 4.2, 4.2, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_WingChamber", 106, -58, 0, 4.2, 4.2, "TrimCyan")
makeHeroPlinth(foundryArt, "Red_ReactorWingChamber", -106, 58, 0, 4.2, 4.2, "TrimOrange")
makeHeroPlinth(foundryArt, "Blue_ReactorWingChamber", 106, 58, 0, 4.2, 4.2, "TrimOrange")

Kit.placeAssetClone(TEMPLATES.ContainmentCanister, foundryArt, "ReactorHeroCanister", { 0, 12.15, 76 }, 0, 0.50, false)
makeHeroPlinth(foundryArt, "Red_ReactorGenerator", -62, 74, 0, 9.8, 5.4, "TrimOrange")
makeHeroPlinth(foundryArt, "Blue_ReactorGenerator", 62, 74, 0, 9.8, 5.4, "TrimOrange")
makeHeroPlinth(foundryArt, "Red_ReactorTelemetryPanel", -80, 116, 32, 3.0, 2.6, "TrimOrange")
makeHeroPlinth(foundryArt, "Blue_ReactorTelemetryPanel", 80, 116, -32, 3.0, 2.6, "TrimOrange")
makeHeroPlinth(foundryArt, "Red_ForgeContainer", -14, 118, 180, 4.4, 4.4, "TrimOrange")
makeHeroPlinth(foundryArt, "Blue_ForgeContainer", 14, 118, 180, 4.4, 4.4, "TrimOrange")
makeHeroPlinth(cryoArt, "Red_SpawnCrateN", -122, -24, 30, 3.8, 3.8, "TrimCyan")
makeHeroPlinth(cryoArt, "Blue_SpawnCrateN", 122, -24, -30, 3.8, 3.8, "TrimCyan")
makeHeroPlinth(foundryArt, "Red_SpawnCrateS", -122, 24, -30, 3.8, 3.8, "TrimOrange")
makeHeroPlinth(foundryArt, "Blue_SpawnCrateS", 122, 24, 30, 3.8, 3.8, "TrimOrange")

-- Gantry N/S Trim, Under-Bracing, Deck Seam Ribs, Upper Tactical Cover & Segmented Safety Railings
Kit.makePart(cryoArt, "GantryNFrontTrim", { 0, 11.1, -67.85 }, { 112, 0.3, 0.35 }, nil, "TrimCyan", "Neon", true)
Kit.makePart(cryoArt, "GantryNBackTrim", { 0, 11.1, -88.15 }, { 112, 0.3, 0.35 }, nil, "TrimCyan", "Neon", true)
Kit.makePart(cryoArt, "GantryNGirder", { 0, 10.1, -78 }, { 110, 0.9, 18 }, nil, "WallRib", "Metal", true)
for _, rx in { -44, -28, -12, 0, 12, 28, 44 } do
    Kit.makePart(
        cryoArt,
        ("GantryNDeckSeam_%d"):format(rx),
        { rx, 11.51, -78 },
        { 0.45, 0.04, 18.6 },
        nil,
        "WallRib",
        "Metal",
        true
    )
end
for _, gx in { -52, -32, -16, 16, 32, 52 } do
    Kit.buildIBeam(cryoArt, ("GantryNColL_%d"):format(gx), gx, -69.5, 10.4, 2.0, 2.0, "WallRib", false)
    Kit.buildIBeam(cryoArt, ("GantryNColR_%d"):format(gx), gx, -86.5, 10.4, 2.0, 2.0, "WallRib", false)
    local bulk = Kit.makePart(
        cryoArt,
        ("GantryUnderLight_%d"):format(gx),
        { gx, 9.5, -78 },
        { 4.2, 0.3, 1.8 },
        nil,
        "SkylightWhite",
        "Neon",
        true
    )
    Kit.addLight(bulk, Color3.fromRGB(190, 232, 255), 0.95, 28, false)
end
buildRailingX(cryoArt, "GantryNBackRail", -55, 55, 11.5, -87.5, "TrimCyan")
buildRailingX(cryoArt, "GantryNFrontRailL", -55, -20, 11.5, -68.5, "TrimCyan")
buildRailingX(cryoArt, "GantryNFrontRailC", -10, 10, 11.5, -68.5, "TrimCyan")
buildRailingX(cryoArt, "GantryNFrontRailR", 20, 55, 11.5, -68.5, "TrimCyan")
Kit.buildBlastShield(mainPieces, cryoArt, "Red_GantryNCover", { -28, 11.5, -76.5 }, 14, 6.2, 3.0, 1.6, "TrimCyan")
Kit.buildBlastShield(mainPieces, cryoArt, "Blue_GantryNCover", { 28, 11.5, -76.5 }, -14, 6.2, 3.0, 1.6, "TrimCyan")

Kit.makePart(foundryArt, "GantrySTrim", { 0, 11.1, 97.8 }, { 104, 0.45, 0.4 }, nil, "TrimOrange", "Neon", true)
Kit.makePart(foundryArt, "GantrySBackTrim", { 0, 11.1, 114.2 }, { 104, 0.45, 0.4 }, nil, "TrimOrange", "Neon", true)
Kit.makePart(foundryArt, "GantrySGirder", { 0, 10.1, 106 }, { 102, 0.9, 14 }, nil, "WallRib", "Metal", true)
for _, rx in { -40, -24, -8, 8, 24, 40 } do
    Kit.makePart(
        foundryArt,
        ("GantrySDeckSeam_%d"):format(rx),
        { rx, 11.51, 106 },
        { 0.45, 0.04, 14.6 },
        nil,
        "WallRib",
        "Metal",
        true
    )
end
for _, gx in { -48, -32, -16, 16, 32, 48 } do
    Kit.buildIBeam(foundryArt, ("GantrySColL_%d"):format(gx), gx, 99.0, 10.4, 2.0, 2.0, "WallRib", false)
    Kit.buildIBeam(foundryArt, ("GantrySColR_%d"):format(gx), gx, 113.0, 10.4, 2.0, 2.0, "WallRib", false)
    local sBulk = Kit.makePart(
        foundryArt,
        ("GantrySUnderLight_%d"):format(gx),
        { gx, 9.5, 106 },
        { 4.2, 0.3, 1.8 },
        nil,
        "SkylightWarm",
        "Neon",
        true
    )
    Kit.addLight(sBulk, "OrangeLight", 1.1, 28, false)
end
buildRailingX(foundryArt, "GantrySBackRail", -51, 51, 11.5, 113.5, "TrimOrange")
buildRailingX(foundryArt, "GantrySFrontRailL", -51, -18, 11.5, 98.5, "TrimOrange")
buildRailingX(foundryArt, "GantrySFrontRailC", -8, 8, 11.5, 98.5, "TrimOrange")
buildRailingX(foundryArt, "GantrySFrontRailR", 18, 51, 11.5, 98.5, "TrimOrange")
Kit.buildBlastShield(mainPieces, foundryArt, "Red_GantrySCover", { -26, 11.5, 104.5 }, -14, 6.2, 3.0, 1.6, "TrimOrange")
Kit.buildBlastShield(mainPieces, foundryArt, "Blue_GantrySCover", { 26, 11.5, 104.5 }, 14, 6.2, 3.0, 1.6, "TrimOrange")

-- South Wall Reactor Heat-Exchanger Manifolds (balances CryoTube_1..4 silhouette along Z = 121.5)
for _, ex in { { name = "SouthExchanger_West", x = -32 }, { name = "SouthExchanger_East", x = 32 } } do
    Kit.makePart(
        foundryArt,
        ex.name .. "_Plinth",
        { ex.x, 0.20, 121.5 },
        { 6.8, 0.40, 5.2 },
        nil,
        "CatwalkSteel",
        "DiamondPlate",
        false
    )
    Kit.makePart(
        foundryArt,
        ex.name .. "_Trim",
        { ex.x, 0.42, 118.95 },
        { 7.0, 0.14, 0.3 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
    Kit.makeCylinder(inside, ex.name .. "_Vessel", { ex.x, 3.6, 121.5 }, 6.4, 3.6, "WallRib", "Metal", false)
    Kit.makeCylinder(foundryArt, ex.name .. "_CoreBand", { ex.x, 3.6, 121.5 }, 0.7, 3.82, "TrimOrange", "Neon", false)
    Kit.makeCylinder(
        foundryArt,
        ex.name .. "_TopCap",
        { ex.x, 7.0, 121.5 },
        0.5,
        4.1,
        "CatwalkSteel",
        "DiamondPlate",
        false
    )
    Kit.makePipeSegment(
        foundryArt,
        ex.name .. "_Riser",
        { ex.x, 7.2, 124.2 },
        { ex.x, 25.0, 124.2 },
        1.1,
        "PipeSteel",
        "Metal",
        3
    )
    Kit.buildEmberPlume(foundryArt, ex.name .. "_Embers", { ex.x, 0.35, 118.2 })
    Kit.buildSteamVent(foundryArt, ex.name .. "_Steam", { ex.x, 7.2, 120.2 }, Enum.NormalId.Front, "OrangeLight")
    local exNode = Kit.makePart(
        foundryArt,
        ex.name .. "_Lamp",
        { ex.x, 4.8, 119.3 },
        { 0.4, 0.4, 0.4 },
        nil,
        "TrimOrange",
        "Neon",
        true
    )
    Kit.addLight(exNode, "OrangeLight", 1.1, 24, false)
end

-- Plumbed Manifold Risers for Wall & Bulkhead Pipe Valves + Electrical Conduit Risers for Cage Wall Lights
for _, vz in { -62, 62 } do
    for _, side in { { tag = "W", sx = -1 }, { tag = "E", sx = 1 } } do
        local riser = Kit.makePipeSegment(
            foundryArt,
            ("WallValveRiser%s_%d"):format(side.tag, vz),
            { side.sx * 126.6, 2.92, vz },
            { side.sx * 126.6, 23.0, vz },
            0.65,
            "PipeSteel",
            "Metal",
            3
        )
        if riser then
            riser.CanCollide = true
        end
        Kit.makePipeSegment(
            foundryArt,
            ("WallValveTee%s_%d"):format(side.tag, vz),
            { side.sx * 126.8, 23.0, vz },
            { side.sx * 125.2, 23.0, vz },
            0.65,
            "PipeSteel",
            "Metal",
            0
        )
    end
end
for _, vx in { -28, 28 } do
    Kit.makePipeSegment(
        cryoArt,
        ("BulkheadValveRiser_%d"):format(vx),
        { vx, 2.6, -29.82 },
        { vx, 18.0, -29.82 },
        0.55,
        "PipeSteel",
        "Metal",
        2
    )
end
for _, lz in { -56, -14, 14, 56 } do
    for _, sx in { -1, 1 } do
        local wx = sx * 127.45
        Kit.makePart(
            foundryArt,
            ("LightCagePlate_%d_%d"):format(sx, lz),
            { wx, 8.4, lz },
            { 0.3, 2.0, 2.0 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        Kit.makePipeSegment(
            foundryArt,
            ("LightCageConduit_%d_%d"):format(sx, lz),
            { sx * 127.2, 9.4, lz },
            { sx * 127.2, 23.0, lz },
            0.32,
            "DarkSteel",
            "Metal",
            2
        )
    end
end
-- Dedicated corner alcove uplights so console workstations are warmly visible
for _, cx in { -96, 96 } do
    for _, cz in { -116, 116 } do
        local isSouth = cz > 0
        local cornerLamp = Kit.makePart(
            foundryArt,
            ("CornerAlcoveLight_%d_%d"):format(cx, cz),
            { cx, 18.0, cz },
            { 6.0, 0.3, 3.0 },
            nil,
            isSouth and "SkylightWarm" or "SkylightWhite",
            "Neon",
            true
        )
        Kit.addLight(
            cornerLamp,
            isSouth and Color3.fromRGB(255, 204, 165) or Color3.fromRGB(205, 232, 255),
            1.4,
            52,
            false
        )
    end
end

-- Fans, Cranes & Clamped Perimeter Pipes
buildWallFan(cryoArt, "NorthFan_West", -54, 15, -127.2, "CryoGlow")
buildWallFan(cryoArt, "NorthFan_East", 54, 15, -127.2, "CryoGlow")
buildWallFan(foundryArt, "SouthFan_West", -54, 15, 127.2, "TrimOrange")
buildWallFan(foundryArt, "SouthFan_East", 54, 15, 127.2, "TrimOrange")
buildOverheadCrane(cryoArt, 28.0, -98, "TrimCyan")
buildOverheadCrane(foundryArt, 28.0, 56, "TrimOrange")

Kit.makePipeSegment(cryoArt, "NorthPipeUpper", { -120, 25, -125.2 }, { 120, 25, -125.2 }, 3.0, "PipeSteel", "Metal", 24)
Kit.makePipeSegment(
    cryoArt,
    "NorthPipeLower",
    { -120, 21.4, -125.2 },
    { 120, 21.4, -125.2 },
    1.8,
    "DarkSteel",
    "Metal",
    24
)
Kit.makePipeSegment(
    foundryArt,
    "SouthPipeUpper",
    { -120, 25, 125.2 },
    { 120, 25, 125.2 },
    3.0,
    "AmberDeck",
    "Metal",
    24
)
Kit.makePipeSegment(
    foundryArt,
    "SouthPipeLower",
    { -120, 21.4, 125.2 },
    { 120, 21.4, 125.2 },
    1.8,
    "DarkSteel",
    "Metal",
    24
)
Kit.makePipeSegment(
    foundryArt,
    "WestPipeUpper",
    { -125.2, 23, -120 },
    { -125.2, 23, 120 },
    2.2,
    "PipeSteel",
    "Metal",
    24
)
Kit.makePipeSegment(foundryArt, "EastPipeUpper", { 125.2, 23, -120 }, { 125.2, 23, 120 }, 2.2, "PipeSteel", "Metal", 24)

Kit.assertFloorClearance(geometry, -0.02)

fs.writeFile(SOURCE_PATH, roblox.serializeModel({ root }))
print("Rebuilt SciFiFoundry with Main Lane upgrades + Gritty Industrial Kit (Zero floor violations)!")
