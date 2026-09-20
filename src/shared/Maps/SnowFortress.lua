-- Snow Fortress: ground-first Convergence battlefield.
-- Contextual traversal uses the shared TraversalService; ground access stays primary.
local map = {
    Name = "SnowFortress",
    Finale = { EligibleIds = { "gate", "yard", "keep" } },
    Size = 500,
    WallHeight = 36,
    Seed = 1129,
    Revision = "exterior-fortress-v2",

    Spawns = {
        Red = {
            { -210, 2, -20 },
            { -210, 2, -12 },
            { -210, 2, -4 },
            { -210, 2, 4 },
            { -210, 2, 12 },
            { -210, 2, 20 },
        },
        Blue = {
            { 210, 2, -20 },
            { 210, 2, -12 },
            { 210, 2, -4 },
            { 210, 2, 4 },
            { 210, 2, 12 },
            { 210, 2, 20 },
        },
    },

    Objectives = {
        {
            Id = "gate",
            Name = "Gate Courtyard",
            pos = { -22, 1, -122 },
            radius = 18,
            halfHeight = 9,
            Phases = { 1, 2, 3 },
        },
        {
            Id = "yard",
            Name = "Service Yard",
            pos = { -22, 1, 122 },
            radius = 18,
            halfHeight = 9,
            Phases = { 1, 2, 3 },
        },
        { Id = "keep", Name = "Command Keep", pos = { 58, 1, 0 }, radius = 17, halfHeight = 9, Phases = { 1, 2, 3 } },
    },
    Vista = { pos = { -225, 58, -205 }, look = { 20, 8, 0 }, seconds = 3 },

    SafetyAlwaysOn = true,
    RecoveryY = -8,
    Bounds = { min = { -245, -12, -215 }, max = { 245, 105, 215 } },
    InvalidRegions = {},
    SafeRegions = {
        { name = "Red Spawn Pocket", pos = { -210, 8, 0 }, size = { 52, 24, 70 } },
        { name = "Blue Spawn Pocket", pos = { 210, 8, 0 }, size = { 52, 24, 70 } },
        { name = "Keep Interior", pos = { 58, 10, 0 }, size = { 70, 30, 76 } },
    },
    SafePoints = {
        { name = "Red Staging", pos = { -195, 1, 0 } },
        { name = "Blue Staging", pos = { 195, 1, 0 } },
        { name = "Gate Courtyard", pos = { -22, 1, -122 } },
        { name = "Service Yard", pos = { -22, 1, 122 } },
        { name = "Command Keep West", pos = { 30, 1, 0 } },
        { name = "Command Keep East", pos = { 86, 1, 0 } },
    },
    Barrier = {
        { pos = { 0, 6, -216.5 }, size = { 490, 12, 1.5 } },
        { pos = { 0, 6, 216.5 }, size = { 490, 12, 1.5 } },
        { pos = { -246.5, 6, 0 }, size = { 1.5, 12, 430 } },
        { pos = { 246.5, 6, 0 }, size = { 1.5, 12, 430 } },
    },

    -- Generic ground-route records: both spawn sides have an authored approach
    -- to every district, plus independent north/south flanks into each finale.
    GroundRoutes = {
        {
            Id = "gate-west-breach",
            DistrictId = "gate",
            Side = "Red",
            Kind = "direct",
            From = { -190, 1, -24 },
            To = { -22, 1, -122 },
            Waypoints = { { -190, 1, -24 }, { -125, 1, -70 }, { -70, 1, -108 }, { -22, 1, -122 } },
        },
        {
            Id = "gate-east-ridge",
            DistrictId = "gate",
            Side = "Blue",
            Kind = "covered",
            From = { 190, 1, -24 },
            To = { -22, 1, -122 },
            Waypoints = { { 190, 1, -24 }, { 130, 1, -72 }, { 55, 1, -106 }, { -22, 1, -122 } },
        },
        {
            Id = "yard-west-service",
            DistrictId = "yard",
            Side = "Red",
            Kind = "covered",
            From = { -190, 1, 24 },
            To = { -22, 1, 122 },
            Waypoints = { { -190, 1, 24 }, { -128, 1, 78 }, { -72, 1, 112 }, { -22, 1, 122 } },
        },
        {
            Id = "yard-east-loading",
            DistrictId = "yard",
            Side = "Blue",
            Kind = "direct",
            From = { 190, 1, 24 },
            To = { -22, 1, 122 },
            Waypoints = { { 190, 1, 24 }, { 128, 1, 78 }, { 52, 1, 112 }, { -22, 1, 122 } },
        },
        {
            Id = "keep-west-arc",
            DistrictId = "keep",
            Side = "Red",
            Kind = "direct",
            From = { -190, 1, 0 },
            To = { 30, 1, -18 },
            Waypoints = { { -190, 1, 0 }, { -112, 1, -34 }, { -30, 1, -32 }, { 30, 1, -18 } },
        },
        {
            Id = "keep-east-arc",
            DistrictId = "keep",
            Side = "Blue",
            Kind = "direct",
            From = { 190, 1, 0 },
            To = { 86, 1, 18 },
            Waypoints = { { 190, 1, 0 }, { 142, 1, 38 }, { 105, 1, 32 }, { 86, 1, 18 } },
        },
        {
            Id = "gate-south-flank",
            DistrictId = "gate",
            Side = "Both",
            Kind = "flank",
            From = { -84, 1, -42 },
            To = { -22, 1, -122 },
            Waypoints = { { -84, 1, -42 }, { -98, 1, -90 }, { -66, 1, -144 }, { -22, 1, -122 } },
        },
        {
            Id = "gate-north-flank",
            DistrictId = "gate",
            Side = "Both",
            Kind = "sheltered",
            From = { 80, 1, -52 },
            To = { -22, 1, -122 },
            Waypoints = { { 80, 1, -52 }, { 72, 1, -148 }, { 22, 1, -158 }, { -22, 1, -122 } },
        },
        {
            Id = "yard-north-flank",
            DistrictId = "yard",
            Side = "Both",
            Kind = "flank",
            From = { -84, 1, 42 },
            To = { -22, 1, 122 },
            Waypoints = { { -84, 1, 42 }, { -98, 1, 90 }, { -66, 1, 144 }, { -22, 1, 122 } },
        },
        {
            Id = "yard-south-flank",
            DistrictId = "yard",
            Side = "Both",
            Kind = "sheltered",
            From = { 80, 1, 52 },
            To = { -22, 1, 122 },
            Waypoints = { { 80, 1, 52 }, { 72, 1, 148 }, { 22, 1, 158 }, { -22, 1, 122 } },
        },
        {
            Id = "keep-south-entry",
            DistrictId = "keep",
            Side = "Both",
            Kind = "covered",
            From = { 6, 1, 82 },
            To = { 58, 1, 34 },
            Waypoints = { { 6, 1, 82 }, { 30, 1, 54 }, { 58, 1, 34 } },
        },
        {
            Id = "keep-north-entry",
            DistrictId = "keep",
            Side = "Both",
            Kind = "covered",
            From = { 6, 1, -82 },
            To = { 58, 1, -34 },
            Waypoints = { { 6, 1, -82 }, { 30, 1, -54 }, { 58, 1, -34 } },
        },
    },

    SniperOutposts = {
        {
            Id = "west-signal",
            Name = "West Signal Outpost",
            pos = { -132, 9, -154 },
            radius = 12,
            GroundRouteId = "gate-south-flank",
        },
        {
            Id = "east-relay",
            Name = "East Relay Outpost",
            pos = { 132, 9, 154 },
            radius = 12,
            GroundRouteId = "yard-east-loading",
        },
    },
    LaunchPads = {
        {
            Id = "west-wall-hop",
            pos = { -118, 0.3, 52 },
            target = { -46, 1, 92 },
            vy = 62,
            size = 8,
            GroundAlternative = "yard-west-service",
        },
        {
            Id = "east-wall-hop",
            pos = { 118, 0.3, -52 },
            target = { 46, 1, -92 },
            vy = 62,
            size = 8,
            GroundAlternative = "gate-east-ridge",
        },
    },
    -- Shared traversal service builds prompts and movement from these endpoints.
    ZipLines = {
        {
            Id = "west-ridge-to-gate",
            From = { -154, 10, -142 },
            To = { -76, 5, -132 },
            GroundAlternative = "gate-south-flank",
            Purpose = "Cross the exposed west gate approach without skipping the courtyard entrance",
        },
        {
            Id = "west-service-connector",
            From = { -150, 9, 116 },
            To = { -82, 5, 142 },
            GroundAlternative = "yard-west-service",
            Purpose = "Trade a visible ride for a second Service Yard entry angle",
        },
        {
            Id = "east-ridge-to-gate",
            From = { 154, 10, -142 },
            To = { 78, 5, -132 },
            GroundAlternative = "gate-east-ridge",
            Purpose = "Challenge the north approach from outside the Blue spawn pocket",
        },
        {
            Id = "east-service-connector",
            From = { 150, 9, 116 },
            To = { 82, 5, 142 },
            GroundAlternative = "yard-east-loading",
            Purpose = "Reach the Service Yard flank while remaining visible from the relay outpost",
        },
    },
    GrappleAnchors = {
        {
            Id = "gate-west-wall",
            From = { -86, 1, -154 },
            To = { -56, 7, -142 },
            GroundAlternative = "gate-south-flank",
            Purpose = "Counter the west outpost and gate wall",
        },
        {
            Id = "gate-east-wall",
            From = { 70, 1, -156 },
            To = { 42, 7, -142 },
            GroundAlternative = "gate-east-ridge",
            Purpose = "Offer a readable alternate wall access point",
        },
        {
            Id = "yard-loading-crane",
            From = { -68, 1, 154 },
            To = { -38, 8, 146 },
            GroundAlternative = "yard-north-flank",
            Purpose = "Counter dense loading-yard cover",
        },
        {
            Id = "keep-balcony",
            From = { 28, 1, 30 },
            To = { 48, 12, 22 },
            GroundAlternative = "keep-south-entry",
            Purpose = "Provide the single inner elevated shortcut",
        },
    },

    Environment = {
        ClockTime = 13.2,
        Brightness = 2.2,
        Ambient = Color3.fromRGB(145, 158, 182),
        OutdoorAmbient = Color3.fromRGB(178, 193, 218),
        FogColor = Color3.fromRGB(224, 234, 248),
        FogStart = 330,
        FogEnd = 1450,
        Atmosphere = { Density = 0.25, Haze = 1.2, Glare = 0.04, Color = Color3.fromRGB(224, 234, 248) },
        SunRays = 0.07,
        Bloom = 0.14,
        Saturation = -0.06,
        Contrast = 0.16,
        Tint = Color3.fromRGB(244, 248, 255),
    },
    Palette = {
        Concrete = Color3.fromRGB(68, 76, 90),
        ConcreteDark = Color3.fromRGB(38, 45, 56),
        Steel = Color3.fromRGB(126, 137, 153),
        Gate = Color3.fromRGB(181, 143, 88),
        Service = Color3.fromRGB(105, 132, 106),
        Command = Color3.fromRGB(105, 108, 132),
        Cover = Color3.fromRGB(89, 98, 112),
        Hazard = Color3.fromRGB(244, 153, 52),
        Lamp = Color3.fromRGB(255, 225, 166),
        Marker = Color3.fromRGB(255, 230, 80),
        Mountain = Color3.fromRGB(166, 181, 207),
    },
    Terrain = {
        GroundMaterial = Enum.Material.Snow,
        GroundColor = Color3.fromRGB(235, 242, 250),
        Hills = {
            { -170, -13, -95, 24 },
            { -168, -13, 94, 25 },
            { 172, -13, -96, 24 },
            { 170, -13, 96, 25 },
            { -18, -16, -190, 20 },
            { -20, -16, 190, 20 },
        },
        Mountains = {
            { 0, -90, -520, 250 },
            { 0, -90, 520, 250 },
            { -520, -100, 0, 260 },
            { 520, -100, 0, 260 },
        },
    },

    Center = {
        -- Spawn pockets have two exits and hard north/south line-of-sight blockers.
        {
            kind = "block",
            name = "RedSpawnBack",
            pos = { -226, 6, 0 },
            size = { 4, 12, 68 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "RedSpawnNorth",
            pos = { -205, 4, -34 },
            size = { 46, 8, 4 },
            color = "Concrete",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "RedSpawnSouth",
            pos = { -205, 4, 34 },
            size = { 46, 8, 4 },
            color = "Concrete",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "BlueSpawnBack",
            pos = { 226, 6, 0 },
            size = { 4, 12, 68 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "BlueSpawnNorth",
            pos = { 205, 4, -34 },
            size = { 46, 8, 4 },
            color = "Concrete",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "BlueSpawnSouth",
            pos = { 205, 4, 34 },
            size = { 46, 8, 4 },
            color = "Concrete",
            material = "Concrete",
        },

        -- Gate Courtyard: open mid-range ground and two offset breaches.
        {
            kind = "block",
            name = "GateApron",
            pos = { -22, 0.15, -122 },
            size = { 112, 0.3, 82 },
            color = "Gate",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "Gatehouse",
            pos = { -22, 8, -165 },
            size = { 54, 16, 12 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "GatePylonW",
            pos = { -72, 7, -126 },
            size = { 9, 14, 34 },
            color = "Concrete",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "GatePylonE",
            pos = { 28, 7, -118 },
            size = { 9, 14, 34 },
            color = "Concrete",
            material = "Concrete",
        },
        { kind = "block", name = "GateCoverW", pos = { -48, 3, -104 }, size = { 16, 6, 6 }, color = "Cover" },
        { kind = "block", name = "GateCoverE", pos = { 5, 3, -139 }, size = { 16, 6, 6 }, color = "Cover" },
        { kind = "beacon", name = "GateBeacon", pos = { -22, 18, -165 }, color = "Gate" },

        -- Service Yard: dense staggered cover and four open approach edges.
        {
            kind = "block",
            name = "ServiceApron",
            pos = { -22, 0.15, 122 },
            size = { 116, 0.3, 86 },
            color = "Service",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "ServiceHall",
            pos = { -48, 8, 165 },
            size = { 50, 16, 12 },
            color = "ConcreteDark",
            material = "Metal",
        },
        {
            kind = "block",
            name = "LoadingBay",
            pos = { 25, 6, 157 },
            size = { 32, 12, 18 },
            color = "Concrete",
            material = "Metal",
        },
        { kind = "block", name = "ServiceCrateA", pos = { -58, 3, 105 }, size = { 12, 6, 12 }, color = "Cover" },
        { kind = "block", name = "ServiceCrateB", pos = { -22, 3, 140 }, size = { 15, 6, 9 }, color = "Cover" },
        { kind = "block", name = "ServiceCrateC", pos = { 12, 3, 111 }, size = { 10, 6, 16 }, color = "Cover" },
        { kind = "block", name = "ServiceCrateD", pos = { 38, 3, 137 }, size = { 12, 6, 10 }, color = "Cover" },
        { kind = "beacon", name = "ServiceBeacon", pos = { -48, 18, 165 }, color = "Service" },

        -- Command Keep: four ground doors and one exposed balcony shortcut.
        {
            kind = "block",
            name = "KeepFloor",
            pos = { 58, 0.15, 0 },
            size = { 74, 0.3, 78 },
            color = "Command",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepNorthW",
            pos = { 39, 7, -38 },
            size = { 28, 14, 4 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepNorthE",
            pos = { 81, 7, -38 },
            size = { 22, 14, 4 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepSouthW",
            pos = { 35, 7, 38 },
            size = { 20, 14, 4 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepSouthE",
            pos = { 77, 7, 38 },
            size = { 30, 14, 4 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepWestN",
            pos = { 21, 7, -24 },
            size = { 4, 14, 24 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepWestS",
            pos = { 21, 7, 24 },
            size = { 4, 14, 24 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepEastN",
            pos = { 95, 7, -24 },
            size = { 4, 14, 24 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepEastS",
            pos = { 95, 7, 24 },
            size = { 4, 14, 24 },
            color = "ConcreteDark",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepCore",
            pos = { 58, 5, 0 },
            size = { 16, 10, 18 },
            color = "Cover",
            material = "Concrete",
        },
        {
            kind = "block",
            name = "KeepBalcony",
            pos = { 58, 11.5, 22 },
            size = { 28, 1, 10 },
            color = "Steel",
            material = "Metal",
        },
        { kind = "beacon", name = "KeepBeacon", pos = { 58, 21, 0 }, color = "Command" },

        -- Exactly two outposts, each with a ground ramp and rear shield.
        {
            kind = "block",
            name = "WestOutpostDeck",
            pos = { -132, 7.5, -154 },
            size = { 24, 1, 18 },
            color = "Steel",
            material = "Metal",
        },
        {
            kind = "block",
            name = "WestOutpostRamp",
            pos = { -146, 3.6, -154 },
            size = { 18, 1, 10 },
            rot = { 0, 0, -25 },
            color = "Steel",
            material = "Metal",
        },
        {
            kind = "block",
            name = "WestOutpostShield",
            pos = { -120, 10, -154 },
            size = { 2, 6, 18 },
            color = "ConcreteDark",
        },
        {
            kind = "block",
            name = "EastOutpostDeck",
            pos = { 132, 7.5, 154 },
            size = { 24, 1, 18 },
            color = "Steel",
            material = "Metal",
        },
        {
            kind = "block",
            name = "EastOutpostRamp",
            pos = { 146, 3.6, 154 },
            size = { 18, 1, 10 },
            rot = { 0, 0, -25 },
            color = "Steel",
            material = "Metal",
        },
        {
            kind = "block",
            name = "EastOutpostShield",
            pos = { 120, 10, 154 },
            size = { 2, 6, 18 },
            color = "ConcreteDark",
        },

        -- Exterior cover breaks long sightlines without sealing a lane.
        { kind = "block", name = "WestNorthCoverA", pos = { -158, 3, -62 }, size = { 18, 6, 8 }, color = "Cover" },
        { kind = "block", name = "WestNorthCoverB", pos = { -112, 3, -96 }, size = { 10, 6, 18 }, color = "Cover" },
        { kind = "block", name = "WestSouthCoverA", pos = { -158, 3, 62 }, size = { 18, 6, 8 }, color = "Cover" },
        { kind = "block", name = "WestSouthCoverB", pos = { -112, 3, 96 }, size = { 10, 6, 18 }, color = "Cover" },
        { kind = "block", name = "EastNorthCoverA", pos = { 158, 3, -62 }, size = { 18, 6, 8 }, color = "Cover" },
        { kind = "block", name = "EastNorthCoverB", pos = { 112, 3, -96 }, size = { 10, 6, 18 }, color = "Cover" },
        { kind = "block", name = "EastSouthCoverA", pos = { 158, 3, 62 }, size = { 18, 6, 8 }, color = "Cover" },
        { kind = "block", name = "EastSouthCoverB", pos = { 112, 3, 96 }, size = { 10, 6, 18 }, color = "Cover" },
    },
}

-- Assemble a consistent fortress kit. Geometry remains map-owned; no mode logic.
local function block(name, pos, size, color, material)
    table.insert(map.Center, {
        kind = "block",
        name = name,
        pos = pos,
        size = size,
        color = color or "Concrete",
        material = material or "Slate",
    })
end

-- Four wall sections per side leave three 32-stud ground gates. Snow caps,
-- buttresses and corner towers give the perimeter a recognizable silhouette.
for _, side in { -1, 1 } do
    for index, section in { { -154, 48 }, { -56, 80 }, { 56, 80 }, { 154, 48 } } do
        block("Curtain" .. side .. "_" .. index, { side * 104, 9, section[1] }, { 6, 18, section[2] })
        block(
            "WallSnow" .. side .. "_" .. index,
            { side * 104, 18.3, section[1] },
            { 7, 0.6, section[2] },
            "Snow",
            "Snow"
        )
    end
    for _, z in { -112, 0, 112 } do
        block("GateLintel" .. side .. "_" .. z, { side * 104, 19, z }, { 8, 4, 32 }, "Steel", "Metal")
        for _, edge in { -1, 1 } do
            block("GatePier" .. side .. "_" .. z .. "_" .. edge, { side * 104, 10, z + edge * 18 }, { 10, 20, 5 })
        end
    end
    block("EndWall" .. side, { 0, 9, side * 178 }, { 208, 18, 6 })
    block("EndSnow" .. side, { 0, 18.3, side * 178 }, { 208, 0.6, 7 }, "Snow", "Snow")
    for _, x in { -104, 104 } do
        block("Tower" .. side .. "_" .. x, { x, 14, side * 178 }, { 18, 28, 18 }, "ConcreteDark")
        block("TowerCrown" .. side .. "_" .. x, { x, 28, side * 178 }, { 22, 2, 22 }, "Steel", "Metal")
        block("TowerSnow" .. side .. "_" .. x, { x, 29.3, side * 178 }, { 22, 0.6, 22 }, "Snow", "Snow")
    end
    -- A front screen splits each staging pocket into two protected exits.
    block("SpawnScreen" .. side, { side * 185, 6, 0 }, { 4, 12, 26 })
end
map.Palette.Snow = Color3.fromRGB(235, 242, 250)

-- Keep lies on the centre line: neither exterior spawn gets a short direct run.
-- Gate and yard remain offset, with opposing-side route timings to be playtested.
for _, piece in map.Center do
    if piece.name == "GatePylonW" or piece.name == "GatePylonE" then
        piece.pos[3] = -150
        piece.size[3] = 18
    end
    if piece.name:sub(1, 4) == "Keep" then
        piece.pos[1] -= 58
    end
end
map.Objectives[3].pos[1] = 0
map.SafeRegions[3].pos[1] = 0
map.SafePoints[5].pos[1] = -28
map.SafePoints[6].pos[1] = 28
for _, route in map.GroundRoutes do
    if route.DistrictId ~= "keep" and route.Side ~= "Both" then
        local side = route.Side == "Red" and -1 or 1
        local direction = route.DistrictId == "gate" and -1 or 1
        route.From = { side * 190, 1, direction * 24 }
        route.Waypoints = {
            route.From,
            { side * 150, 1, direction * 112 },
            { side * 104, 1, direction * 112 },
            { side * 82, 1, direction * 122 },
            route.To,
        }
    end
    if route.DistrictId == "keep" then
        route.To[1] -= 58
        -- Re-author these lanes to pass through the actual centre gates and doors.
        if route.Side == "Red" then
            route.Waypoints = { { -190, 1, -24 }, { -160, 1, 0 }, { -104, 1, 0 }, { -28, 1, 0 } }
        elseif route.Side == "Blue" then
            route.Waypoints = { { 190, 1, 24 }, { 160, 1, 0 }, { 104, 1, 0 }, { 28, 1, 0 } }
        else
            for _, point in route.Waypoints do
                point[1] -= 58
            end
        end
        route.From = route.Waypoints[1]
        route.To = route.Waypoints[#route.Waypoints]
    end
end

-- Replace the detached, wrongly sloped outpost ramps with two stair approaches.
-- One-stud rises over 2.5-stud treads; top meets the eight-stud deck.
for index = #map.Center, 1, -1 do
    if map.Center[index].name:find("OutpostRamp") then
        table.remove(map.Center, index)
    end
end
for _, outpost in map.SniperOutposts do
    local x, z = outpost.pos[1], outpost.pos[3]
    for _, direction in { -1, 1 } do
        for step = 1, 8 do
            block(
                outpost.Id .. "Stair" .. direction .. "_" .. step,
                { x, step / 2, z + direction * (29 - step * 2.5) },
                { 9, step, 2.5 },
                "Steel",
                "Metal"
            )
        end
    end
end

-- Low zip origins are reachable from ground and pass through the open gates.
for _, line in map.ZipLines do
    local side = line.From[1] < 0 and -1 or 1
    local z = line.From[3] < 0 and -112 or 112
    line.From = { side * 150, 4, z }
    line.To = { side * 76, 4, z }
end
for index, pad in map.LaunchPads do
    local side = index == 1 and -1 or 1
    local z = 0
    pad.pos = { side * 150, 0.3, z }
    pad.target = { side * 76, 1, z }
    pad.GroundAlternative = index == 1 and "keep-west-arc" or "keep-east-arc"
end
-- The straight cable travels through the open gate, below its 17-stud lintel.
-- Grapples terminate on real ledges rather than floating points.
for index, anchor in map.GrappleAnchors do
    if anchor.Id == "keep-balcony" then
        anchor.From = { -28, 4, 22 }
        anchor.To = { -10, 15, 22 }
    else
        local x, z = anchor.To[1], anchor.To[3]
        local height = anchor.To[2] - 3
        anchor.From[2] = 4
        block("GrappleLedge" .. index, { x, height - 0.5, z }, { 14, 1, 10 }, "Steel", "Metal")
        for step = 1, height do
            block(
                "GrappleStep" .. index .. "_" .. step,
                { x + 8 + (height - step) * 2.5, step / 2, z },
                { 2.5, step, 8 },
                "Steel",
                "Metal"
            )
        end
    end
end
for step = 1, 12 do
    block("KeepBalconyStep" .. step, { -19, step / 2, -11 + step * 2.5 }, { 8, step, 2.5 }, "Steel", "Metal")
end
block("KeepBalconyJoin", { -14, 11.5, 22 }, { 10, 1, 10 }, "Steel", "Metal")

-- Architectural detail is grouped into large readable shapes, not tiny clutter.
for _, z in { -178, 178 } do
    for x = -80, 80, 20 do
        block("Buttress" .. x .. "_" .. z, { x, 10, z }, { 4, 20, 10 })
        block("Battlement" .. x .. "_" .. z, { x, 20, z }, { 8, 4, 7 })
    end
end
block("KeepSignalTower", { 0, 20, 0 }, { 12, 20, 12 }, "ConcreteDark")
block("KeepSignalCrown", { 0, 31, 0 }, { 16, 2, 16 }, "Steel", "Metal")
block("KeepSignalSnow", { 0, 32.3, 0 }, { 16, 0.6, 16 }, "Snow", "Snow")

return map
