-- Highway Overpass: a sunset 8-lane desert-highway Convergence map.
-- Gameplay:
--   - Widened 8-lane divided highway (Z = -48..+48) with crashed cars scattered across the outer
--     lanes for tactical cover and car-to-car flanking, funneling into the Central Plaza (A, B, C).
--   - One Express Vehicle Jump Ramp per side on the center lane (Z = 0), allowing Combat Buggies
--     to launch straight over the Central Plaza (B) and land behind enemy lines.
--   - Two outer flanking routes: North Elevated Service Catwalk (Z = -56, Y = 4) with Sniper
--     Overlooks, and South Sunken Drainage Underpass (Z = +56, Y = -4) for covered CQC pushes.

local Center = {}
local Mirrored = {}

local function add(list, piece)
    table.insert(list, piece)
end

-- Multi-part crashed highway vehicle (solid body + cabin for honest waist/head-high cover).
local function addCrashedCar(list, name, x, z, yaw, bodyColor)
    add(list, {
        kind = "block",
        name = name .. "_Body",
        pos = { x, 1.1, z },
        size = { 10.5, 2.2, 4.8 },
        rot = { 0, yaw, 0 },
        color = bodyColor,
        material = "Metal",
    })
    add(list, {
        kind = "block",
        name = name .. "_Cabin",
        pos = { x, 2.8, z },
        size = { 5.2, 1.4, 4.4 },
        rot = { 0, yaw, 0 },
        color = bodyColor,
        material = "SmoothPlastic",
    })
    add(list, {
        kind = "block",
        name = name .. "_Glass",
        pos = { x, 2.75, z },
        size = { 5.4, 0.9, 4.1 },
        rot = { 0, yaw, 0 },
        color = "CarGlass",
        material = "Glass",
        decor = true,
    })
end

-- ============================================================================
-- CENTER GEOMETRY (placed once along X = 0)
-- ============================================================================

-- Widened 8-lane highway deck: X = -165..+165, Z = -48..+48, top surface at Y = 0
add(Center, {
    kind = "block",
    name = "HighwayDeck",
    pos = { 0, -2, 0 },
    size = { 330, 4, 96 },
    color = "Asphalt",
    material = "Asphalt",
})

-- Highway shoulders (concrete curbs)
add(Center, {
    kind = "block",
    name = "ShoulderN",
    pos = { 0, -0.4, -48.5 },
    size = { 330, 1.2, 2 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "ShoulderS",
    pos = { 0, -0.4, 48.5 },
    size = { 330, 1.2, 2 },
    color = "ConcreteLight",
    material = "Concrete",
})

-- Center double-yellow median stripe (decor)
add(Center, {
    kind = "block",
    name = "MedianStripeN",
    pos = { 0, 0.03, -0.6 },
    size = { 310, 0.06, 0.4 },
    color = "RoadYellow",
    material = "SmoothPlastic",
    decor = true,
})
add(Center, {
    kind = "block",
    name = "MedianStripeS",
    pos = { 0, 0.03, 0.6 },
    size = { 310, 0.06, 0.4 },
    color = "RoadYellow",
    material = "SmoothPlastic",
    decor = true,
})

-- North Elevated Service Catwalk (Z = -63..-51, top at Y = 4)
add(Center, {
    kind = "block",
    name = "NorthCatwalkDeck",
    pos = { 0, 3.5, -57 },
    size = { 224, 1, 12 },
    color = "ConcreteMid",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "NorthCatwalkRail",
    pos = { 0, 5.2, -62.5 },
    size = { 224, 2.4, 1 },
    color = "ConcreteDark",
    material = "Concrete",
})

-- South Sunken Drainage Underpass (Z = +51..+63, top at Y = -4)
add(Center, {
    kind = "block",
    name = "SouthDrainDeck",
    pos = { 0, -4.5, 57 },
    size = { 208, 1, 12 },
    color = "ConcreteDark",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "SouthDrainWallOuter",
    pos = { 0, -2.5, 63.5 },
    size = { 208, 5, 1.5 },
    color = "ConcreteMid",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "SouthDrainWallInner",
    pos = { 0, -2.5, 50.5 },
    size = { 208, 5, 1.5 },
    color = "ConcreteMid",
    material = "Concrete",
})

-- Central Plaza (X = 0) cover: toll kiosk island & jersey barriers around A, B, C
add(Center, {
    kind = "block",
    name = "MidTollIsland",
    pos = { 0, 1.5, 0 },
    size = { 6, 3, 10 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "MidTollRoof",
    pos = { 0, 7.5, 0 },
    size = { 8, 1.2, 12 },
    color = "SteelBeam",
    material = "Metal",
})
add(Center, {
    kind = "block",
    name = "MidJerseyN",
    pos = { 0, 1.8, -16 },
    size = { 4, 3.6, 8 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "MidJerseyS",
    pos = { 0, 1.8, 16 },
    size = { 4, 3.6, 8 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "MidCoverA",
    pos = { 0, 1.8, -32 },
    size = { 10, 3.6, 2.5 },
    color = "ConcreteMid",
    material = "Concrete",
})
add(Center, {
    kind = "block",
    name = "MidCoverC",
    pos = { 0, 1.8, 32 },
    size = { 10, 3.6, 2.5 },
    color = "ConcreteMid",
    material = "Concrete",
})

-- Iconic Overhead Highway Sign Gantry at X = 0 (clears jumping buggies cleanly at Y = 32)
add(Center, {
    kind = "block",
    name = "GantryPillarN",
    pos = { 0, 16, -49 },
    size = { 3, 32, 3 },
    color = "SteelBeam",
    material = "Metal",
})
add(Center, {
    kind = "block",
    name = "GantryPillarS",
    pos = { 0, 16, 49 },
    size = { 3, 32, 3 },
    color = "SteelBeam",
    material = "Metal",
})
add(Center, {
    kind = "block",
    name = "GantryCrossbeam",
    pos = { 0, 32, 0 },
    size = { 2.5, 2.5, 100 },
    color = "SteelBeam",
    material = "Metal",
})
add(Center, {
    kind = "block",
    name = "GantrySignBoard",
    pos = { 0, 32, 0 },
    size = { 1.0, 7.5, 32 },
    color = "SignGreen",
    material = "SmoothPlastic",
    decor = true,
})

-- ============================================================================
-- MIRRORED GEOMETRY (Red side X < 0; automatically mirrored to Blue X > 0)
-- ============================================================================

-- Spawn Area Backstop & Protective Jersey Walls
add(Mirrored, {
    kind = "block",
    name = "SpawnBackWall",
    pos = { -162, 5, 0 },
    size = { 4, 10, 98 },
    color = "ConcreteDark",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "SpawnBunkerN",
    pos = { -128, 2.2, -32 },
    size = { 4, 4.4, 16 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "SpawnBunkerS",
    pos = { -128, 2.2, 32 },
    size = { 4, 4.4, 16 },
    color = "ConcreteLight",
    material = "Concrete",
})

-- Highway Funnel Walls: channel the wide 8-lane highway inward toward Central Plaza (X = -32..+32)
add(Mirrored, {
    kind = "block",
    name = "FunnelBarrierN",
    pos = { -58, 3.0, -46 },
    size = { 46, 6.0, 3 },
    color = "ConcreteMid",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "FunnelBarrierS",
    pos = { -58, 3.0, 46 },
    size = { 46, 6.0, 3 },
    color = "ConcreteMid",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "MidChokeWingN",
    pos = { -28, 2.2, -42 },
    size = { 16, 4.4, 3 },
    rot = { 0, -28, 0 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "MidChokeWingS",
    pos = { -28, 2.2, 42 },
    size = { 16, 4.4, 3 },
    rot = { 0, 28, 0 },
    color = "ConcreteLight",
    material = "Concrete",
})

-- ONE Express Vehicle Jump Ramp per side on the center express lane (Z = 0)
-- Rises from X = -72 (Y = 0) at 22 deg up to X = -38 (Y = 13.7), launching straight over Central Plaza (B)!
add(Mirrored, {
    kind = "block",
    name = "JumpRamp",
    pos = { -55, 6.85, 0 },
    size = { 36.7, 1.4, 16 },
    rot = { 0, 0, 22 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "JumpRampCoreA",
    pos = { -45, 3.5, 0 },
    size = { 16, 7.0, 15.4 },
    color = "ConcreteDark",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "JumpRampCoreB",
    pos = { -39, 6.5, 0 },
    size = { 4, 13.0, 15.4 },
    color = "ConcreteDark",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "JumpRampLip",
    pos = { -38.4, 13.7, 0 },
    size = { 1.4, 0.3, 16.1 },
    rot = { 0, 0, 22 },
    color = "HazardOrange",
    material = "Neon",
    decor = true,
})

-- Crashed Cars across the widened outer lanes (cover points & car-to-car flanking routes)
addCrashedCar(Mirrored, "CrashCarN1", -96, -20, 18, "CarRust")
addCrashedCar(Mirrored, "CrashCarN2", -76, -34, -26, "CarTeal")
addCrashedCar(Mirrored, "CrashCarN3", -48, -22, 42, "CarTaxi")
addCrashedCar(Mirrored, "CrashCarN4", -22, -26, -15, "CarSedan")

addCrashedCar(Mirrored, "CrashCarS1", -96, 20, -22, "CarTaxi")
addCrashedCar(Mirrored, "CrashCarS2", -76, 34, 24, "CarSedan")
addCrashedCar(Mirrored, "CrashCarS3", -48, 22, -38, "CarRust")
addCrashedCar(Mirrored, "CrashCarS4", -22, 26, 16, "CarTeal")

-- Additional Jersey cover near mid-lane
add(Mirrored, {
    kind = "block",
    name = "MidLaneCoverN",
    pos = { -20, 1.8, -10 },
    size = { 3, 3.6, 8 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "MidLaneCoverS",
    pos = { -20, 1.8, 10 },
    size = { 3, 3.6, 8 },
    color = "ConcreteLight",
    material = "Concrete",
})

-- North Catwalk Flank Ramps (Y = 0 <-> Y = 4) & Sniper Overlook Perch
add(Mirrored, {
    kind = "block",
    name = "NorthFlankEntryRamp",
    pos = { -98, 2.0, -56 },
    size = { 10.7, 1.0, 10 },
    rot = { 0, 0, 22 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "NorthFlankMidRamp",
    pos = { -26, 2.0, -52 },
    size = { 10.7, 1.0, 10 },
    rot = { 0, 0, -22 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "NorthCatwalkCover1",
    pos = { -48, 5.6, -57 },
    size = { 3, 3.2, 6 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "SniperPerchDeck",
    pos = { -58, 7.5, -65 },
    size = { 16, 1.0, 10 },
    color = "SteelBeam",
    material = "Metal",
})
add(Mirrored, {
    kind = "block",
    name = "SniperPerchRamp",
    pos = { -70, 5.75, -63 },
    size = { 10.7, 1.0, 6 },
    rot = { 0, 0, 22 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "SniperPerchParapet",
    pos = { -58, 9.5, -60.5 },
    size = { 14, 3.0, 1.2 },
    color = "ConcreteMid",
    material = "Concrete",
})

-- South Sunken Drainage Flank Ramps (Y = 0 <-> Y = -4) & Culvert Cover
add(Mirrored, {
    kind = "block",
    name = "SouthFlankEntryRamp",
    pos = { -88, -2.0, 57 },
    size = { 10.7, 1.0, 10 },
    rot = { 0, 0, -22 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "SouthFlankMidRamp",
    pos = { -26, -2.0, 52 },
    size = { 10.7, 1.0, 10 },
    rot = { 0, 0, 22 },
    color = "ConcreteLight",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "SouthDrainPillar",
    pos = { -52, -1.5, 57 },
    size = { 4, 5.0, 6 },
    color = "ConcreteMid",
    material = "Concrete",
})
add(Mirrored, {
    kind = "block",
    name = "SouthDrainArch",
    pos = { -52, 2.0, 57 },
    size = { 6, 2.0, 14 },
    color = "ConcreteDark",
    material = "Concrete",
})

-- Dashed highway lane lines across all 8 lanes (decor)
for _, xOff in { -140, -110, -80, -30, -12 } do
    for _, zLane in { -36, -24, -12, 12, 24, 36 } do
        add(Mirrored, {
            kind = "block",
            name = "LaneDash",
            pos = { xOff, 0.03, zLane },
            size = { 10, 0.06, 0.4 },
            color = "RoadWhite",
            material = "SmoothPlastic",
            decor = true,
        })
    end
end

return {
    Name = "HighwayOverpass",
    DisplayName = "Highway Overpass",
    Size = 350,
    WallHeight = 28,

    Spawns = {
        Red = {
            { -148, 1.5, -32 },
            { -148, 1.5, -12 },
            { -148, 1.5, 12 },
            { -148, 1.5, 32 },
            { -138, 1.5, -20 },
            { -138, 1.5, 20 },
        },
        Blue = {
            { 148, 1.5, -32 },
            { 148, 1.5, -12 },
            { 148, 1.5, 12 },
            { 148, 1.5, 32 },
            { 138, 1.5, -20 },
            { 138, 1.5, 20 },
        },
    },

    Objectives = {
        { Id = "A", Name = "North Overpass", pos = { 0, 0, -25 }, radius = 11, halfHeight = 10, Phases = { 1 } },
        { Id = "B", Name = "Central Plaza", pos = { 0, 0, 0 }, radius = 14, halfHeight = 10, Phases = { 1, 2, 3 } },
        { Id = "C", Name = "South Median", pos = { 0, 0, 25 }, radius = 11, halfHeight = 10, Phases = { 1, 2 } },
    },

    VehicleSpawns = {
        Buggy = {
            seats = 2,
            passengerFire = true,
            respawn = 12,
            abandonedReset = 25,
            pads = {
                { team = "Red", pos = { -122, 0.5, -6 }, yaw = -90 },
                { team = "Red", pos = { -122, 0.5, 6 }, yaw = -90 },
                { team = "Blue", pos = { 122, 0.5, -6 }, yaw = 90 },
                { team = "Blue", pos = { 122, 0.5, 6 }, yaw = 90 },
            },
        },
    },

    SniperOutposts = {
        { Name = "Red North Overlook", pos = { -58, 8.5, -65 }, radius = 9 },
        { Name = "Blue North Overlook", pos = { 58, 8.5, -65 }, radius = 9 },
    },

    Pickups = {
        { kind = "weapon", weapon = "Shotgun", pos = { 0, 1.2, 8.5 }, respawn = 50, duration = 40 },
        { kind = "weapon", weapon = "Wildcat", pos = { 0, 1.2, -8.5 }, respawn = 50, duration = 40 },
        {
            kind = "weapon",
            weapon = "WhiteSniper",
            pos = { -58, 9.0, -65 },
            respawnTuning = "WhiteSniperRespawnSeconds",
            respawnOnDeath = true,
        },
        {
            kind = "weapon",
            weapon = "WhiteSniper",
            pos = { 58, 9.0, -65 },
            respawnTuning = "WhiteSniperRespawnSeconds",
            respawnOnDeath = true,
        },
        { kind = "speed", pos = { -68, 5.0, -57 } },
        { kind = "speed", pos = { 68, 5.0, -57 } },
        { kind = "speed", pos = { -64, -3.0, 57 } },
        { kind = "speed", pos = { 64, -3.0, 57 } },
    },

    Vista = { pos = { -160, 96, 125 }, look = { 0, 6, 0 }, seconds = 2.5 },

    RecoveryY = -22,
    Bounds = { min = { -175, -30, -105 }, max = { 175, 160, 105 } },
    InvalidRegions = {},
    SafeRegions = {},
    SafePoints = {
        { name = "Red Spawn", pos = { -142, 1.5, 0 } },
        { name = "Blue Spawn", pos = { 142, 1.5, 0 } },
        { name = "Central Plaza", pos = { 0, 1.5, 0 } },
        { name = "North Catwalk", pos = { 0, 5.5, -57 } },
        { name = "South Underpass", pos = { 0, -2.5, 57 } },
    },

    Barrier = {
        { pos = { -168, 12, 0 }, size = { 2, 28, 150 } },
        { pos = { 168, 12, 0 }, size = { 2, 28, 150 } },
        { pos = { 0, 12, -64 }, size = { 336, 28, 2 } },
        { pos = { 0, 12, 65 }, size = { 336, 28, 2 } },
    },

    Environment = {
        ClockTime = 17.5,
        Brightness = 2.4,
        Ambient = Color3.fromRGB(128, 108, 102),
        OutdoorAmbient = Color3.fromRGB(168, 138, 118),
        FogColor = Color3.fromRGB(232, 178, 136),
        FogStart = 240,
        FogEnd = 1400,
        Atmosphere = {
            Density = 0.25,
            Haze = 1.4,
            Glare = 0.30,
            Color = Color3.fromRGB(242, 190, 144),
            Decay = Color3.fromRGB(150, 96, 72),
        },
        SunRays = 0.18,
        Bloom = 0.12,
        Saturation = 0.16,
        Contrast = 0.10,
        Tint = Color3.fromRGB(255, 242, 228),
    },

    Palette = {
        Asphalt = Color3.fromRGB(48, 50, 56),
        ConcreteLight = Color3.fromRGB(168, 166, 160),
        ConcreteMid = Color3.fromRGB(124, 122, 118),
        ConcreteDark = Color3.fromRGB(84, 84, 86),
        SteelBeam = Color3.fromRGB(62, 68, 76),
        SignGreen = Color3.fromRGB(26, 102, 58),
        RoadYellow = Color3.fromRGB(235, 190, 52),
        RoadWhite = Color3.fromRGB(228, 228, 228),
        HazardOrange = Color3.fromRGB(255, 145, 36),
        RustContainer = Color3.fromRGB(142, 68, 48),
        CarRust = Color3.fromRGB(158, 76, 52),
        CarTeal = Color3.fromRGB(58, 118, 128),
        CarTaxi = Color3.fromRGB(218, 168, 48),
        CarSedan = Color3.fromRGB(110, 116, 124),
        CarGlass = Color3.fromRGB(70, 96, 112),
    },

    Terrain = {
        Void = true,
    },

    Center = Center,
    Mirrored = Mirrored,
}
