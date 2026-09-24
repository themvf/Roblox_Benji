-- Crucible: gameplay data. The geometry is NOT here, and no future map's will be either.
--
-- Everything you can stand on lives in assets/environment/baked/Crucible.rbxm, built in
-- Studio out of ServerStorage.MapKit and saved as a model. MapService clones it; nothing
-- below places a block. This file holds only what is not geometry -- objectives, spawns,
-- routes, bounds, safety, palette, sky -- because services read those, they have to be
-- diffable, and they are small enough to read in one screen.
--
-- The bake starts as bare ground with a wall around it. That is deliberate: a map you can
-- already walk around is a map you can test a change to, and the first version of every
-- other map in this repo was a thousand lines of Lua that nobody could see until it ran.
--
-- To build it: open Studio, drag ServerStorage.MapKit.Ground and .GUIDE into Workspace to
-- see where the anchors are, assemble the rest of the kit around them, DELETE the GUIDE,
-- then select the model and right-click -> Save to File over
-- assets/environment/baked/Crucible.rbxm. Then run:
--
--     bash tools/save_map.sh -c "what you changed"
--
-- The numbers below describe the empty arena. They are meant to move: once the layout
-- exists, put the GUIDE markers where the real objectives and spawns ended up, read the
-- positions off them, and update this file to match. The gates check the two against each
-- other, so they cannot drift apart silently.
--
-- North = -Z, Blue = west (-X), Red = east (+X).
local map = {
    Name = "Crucible",
    Revision = "blockout-v1",
    Size = 500,
    WallHeight = 12,
    Seed = 4102,
    Finale = { EligibleIds = { "north", "south", "centre" } },

    -- Six exterior spawns a side: the map gates require six, and a line of them spreads a
    -- team out far enough that one grenade at the spawn line is not the whole round.
    Spawns = {
        Blue = { { -210, 0, -20 }, { -210, 0, -12 }, { -210, 0, -4 }, { -210, 0, 4 }, { -210, 0, 12 }, { -210, 0, 20 } },
        Red = { { 210, 0, -20 }, { 210, 0, -12 }, { 210, 0, -4 }, { 210, 0, 4 }, { 210, 0, 12 }, { 210, 0, 20 } },
    },

    -- Three zones on the centre line, equidistant from both spawns, so neither side owns
    -- one by geography before anyone moves. Centre sits at ground level for now; raise its
    -- y the moment there is something built to stand on there, and the GUIDE's centre pole
    -- is what tells you how high that came out.
    Objectives = {
        {
            Id = "north",
            Name = "A — North Field",
            pos = { 0, 0.2, -128 },
            radius = 18,
            halfHeight = 7,
            Phases = { 1, 2, 3 },
        },
        {
            Id = "south",
            Name = "B — South Field",
            pos = { 0, 0.2, 128 },
            radius = 18,
            halfHeight = 7,
            Phases = { 1, 2, 3 },
        },
        {
            Id = "centre",
            Name = "C — Centre",
            pos = { 0, 0.2, 0 },
            radius = 18,
            halfHeight = 7,
            Phases = { 1, 2, 3 },
        },
    },

    Vista = { pos = { -225, 80, -190 }, look = { 0, 8, 0 }, seconds = 3 },
    SafetyAlwaysOn = true,
    RecoveryY = -8,
    Bounds = { min = { -245, -12, -185 }, max = { 245, 85, 185 } },
    InvalidRegions = {},
    SafeRegions = {},

    -- Where SafetyService puts someone who ends up outside the map. Every one of these has
    -- to be somewhere a player can stand in the CURRENT bake -- on flat ground that is all
    -- of them, but if the centre becomes a tower, the centre point has to move up with it
    -- or recovery drops people inside it.
    SafePoints = {
        { name = "Blue exterior", pos = { -200, 1, 0 } },
        { name = "Red exterior", pos = { 200, 1, 0 } },
        { name = "North field", pos = { 0, 1, -128 } },
        { name = "South field", pos = { 0, 1, 128 } },
        { name = "Centre", pos = { 0, 1, 0 } },
    },

    -- Rebuilt live from Bounds on every build, never cloned out of the bake, so these stay
    -- correct even while the geometry inside them is half-finished.
    Barrier = {
        { pos = { 0, 6, -186.5 }, size = { 490, 12, 1.5 } },
        { pos = { 0, 6, 186.5 }, size = { 490, 12, 1.5 } },
        { pos = { -246.5, 6, 0 }, size = { 1.5, 12, 370 } },
        { pos = { 246.5, 6, 0 }, size = { 1.5, 12, 370 } },
    },

    Terrain = {
        GroundMaterial = Enum.Material.Snow,
        GroundColor = Color3.fromRGB(226, 233, 240),
    },

    -- Shared with the kit: kit pieces were cut out of a snow map, so a block placed from
    -- the kit and a block tinted from this palette have to agree or the map reads as two
    -- maps. Change both together.
    Palette = {
        Floor = Color3.fromRGB(180, 184, 190),
        Wall = Color3.fromRGB(102, 110, 122),
        Cover = Color3.fromRGB(122, 130, 140),
        Upper = Color3.fromRGB(154, 165, 180),
        Ramp = Color3.fromRGB(200, 204, 212),
        Deck = Color3.fromRGB(116, 124, 136),
        PadDeck = Color3.fromRGB(74, 80, 88),
        PadMark = Color3.fromRGB(214, 196, 110),
        Scorch = Color3.fromRGB(58, 56, 58),
    },

    Environment = {
        -- "Snowy Sky Box" by @DonTheBears, Creator Store asset 2029216718. Six distinct
        -- face images, which is what a continuous horizon needs; a skybox repeating one
        -- image on all four sides cannot be one.
        Sky = {
            Ft = "rbxassetid://2029211409",
            Bk = "rbxassetid://2029210131",
            Lf = "rbxassetid://2029212393",
            Rt = "rbxassetid://2029212849",
            Up = "rbxassetid://2029213271",
            Dn = "rbxassetid://2029210773",
            CelestialBodiesShown = true,
        },
        ClockTime = 12,
        Brightness = 2,
        Ambient = Color3.fromRGB(160, 160, 160),
        OutdoorAmbient = Color3.fromRGB(170, 170, 170),
        FogStart = 900,
        FogEnd = 3000,
        FogColor = Color3.fromRGB(190, 195, 205),
        Atmosphere = { Density = 0, Haze = 0, Glare = 0, Color = Color3.fromRGB(255, 255, 255) },
        SunRays = 0,
        Bloom = 0,
        Saturation = 0,
        Contrast = 0,
        Tint = Color3.fromRGB(255, 255, 255),
    },

    -- Empty and staying empty. These two placed geometry from Lua, which is the thing this
    -- map exists to stop doing. Anything you would have put here goes in the bake instead.
    Center = {},
    Mirrored = {},

    -- Scenery, authored in Studio and saved to assets/environment/decor/Crucible.rbxmx.
    -- Kept apart from the bake so a prop can be added or removed without re-saving the
    -- whole map, and so nothing decorative can ever be load-bearing.
    Decor = {},
    Symmetry = {},

    -- How the bots walk from a spawn to a zone. On open ground the straight line is the
    -- route; once there are walls, each waypoint has to go round them or bots pile into
    -- the geometry. check_maps verifies the whole path is inside Bounds and unobstructed
    -- against the bake, so a wall dropped across a route is caught before a playtest.
    GroundRoutes = {
        {
            Id = "blue-north",
            DistrictId = "north",
            Side = "Blue",
            Kind = "open",
            From = { -210, 1, -20 },
            To = { 0, 1, -128 },
            Waypoints = { { -210, 1, -20 }, { -150, 1, -60 }, { -70, 1, -105 }, { 0, 1, -128 } },
        },
        {
            Id = "blue-south",
            DistrictId = "south",
            Side = "Blue",
            Kind = "open",
            From = { -210, 1, 20 },
            To = { 0, 1, 128 },
            Waypoints = { { -210, 1, 20 }, { -150, 1, 60 }, { -70, 1, 105 }, { 0, 1, 128 } },
        },
        {
            Id = "blue-centre",
            DistrictId = "centre",
            Side = "Blue",
            Kind = "open",
            From = { -210, 1, 0 },
            To = { 0, 1, 0 },
            Waypoints = { { -210, 1, 0 }, { -140, 1, 0 }, { -70, 1, 0 }, { 0, 1, 0 } },
        },
        {
            Id = "red-north",
            DistrictId = "north",
            Side = "Red",
            Kind = "open",
            From = { 210, 1, -20 },
            To = { 0, 1, -128 },
            Waypoints = { { 210, 1, -20 }, { 150, 1, -60 }, { 70, 1, -105 }, { 0, 1, -128 } },
        },
        {
            Id = "red-south",
            DistrictId = "south",
            Side = "Red",
            Kind = "open",
            From = { 210, 1, 20 },
            To = { 0, 1, 128 },
            Waypoints = { { 210, 1, 20 }, { 150, 1, 60 }, { 70, 1, 105 }, { 0, 1, 128 } },
        },
        {
            Id = "red-centre",
            DistrictId = "centre",
            Side = "Red",
            Kind = "open",
            From = { 210, 1, 0 },
            To = { 0, 1, 0 },
            Waypoints = { { 210, 1, 0 }, { 140, 1, 0 }, { 70, 1, 0 }, { 0, 1, 0 } },
        },
    },

    SniperOutposts = {},
    LaunchPads = {},
    ZipLines = {},
    GrappleAnchors = {},
    RoofHatches = {},
    ReviewViews = {},

    -- Geometry comes from the .rbxm or the map does not load. Without this a missing bake
    -- would build an empty world and look like a working map with nothing in it.
    RequiresBake = true,
}

return map
