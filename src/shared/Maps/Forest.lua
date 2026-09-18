-- Misty pine forest arena. Same lane structure as the greybox, but the cover is
-- rocks and fallen logs, the ground is terrain, and trees fill the space between.
-- Everything is mirrored across X so both teams get the same layout.
-- Positions are {x, y, z} in studs.
return {
    Name = "Forest",
    Size = 240,
    WallHeight = 60, -- invisible boundary walls
    Seed = 1337, -- change for a different tree/rock arrangement

    Spawns = {
        Red = { { -100, 4, -14 }, { -100, 4, 0 }, { -100, 4, 14 }, { -108, 4, -7 }, { -108, 4, 7 }, { -104, 4, 20 } },
        Blue = { { 100, 4, -14 }, { 100, 4, 0 }, { 100, 4, 14 }, { 108, 4, -7 }, { 108, 4, 7 }, { 104, 4, 20 } },
    },

    -- Convergence objectives, all on the centre line: North perch side -> South -> the Lake last
    Objectives = {
        { Name = "North Ridge", pos = { 0, 0, -58 }, radius = 14, Phases = { 1 } },
        { Name = "South Ridge", pos = { 0, 0, 58 }, radius = 14, Phases = { 1, 2 } },
        { Name = "The Lake", pos = { 0, 0, 0 }, radius = 18, Phases = { 1, 2, 3 } },
    },

    -- Rivals look: bright midday, no fog, saturated color blocks, glowing indicators.
    Environment = {
        ClockTime = 13.5,
        Brightness = 2.4,
        Ambient = Color3.fromRGB(120, 130, 140),
        OutdoorAmbient = Color3.fromRGB(150, 165, 180),
        FogColor = Color3.fromRGB(200, 230, 255),
        FogStart = 400,
        FogEnd = 1500,
        Atmosphere = { Density = 0.22, Haze = 0.6, Glare = 0.1, Color = Color3.fromRGB(200, 225, 255) },
        SunRays = 0.05,
        Bloom = 0.5,
        Saturation = 0.25, -- push colors, never desaturate
        Contrast = 0.12,
        Tint = Color3.fromRGB(255, 255, 255),
    },

    -- Color jobs. Environment stays soft; cover and indicators stay loud.
    Palette = {
        Rock = Color3.fromRGB(235, 225, 205), -- pale warm stone: cover reads as light blocks
        RockEdge = Color3.fromRGB(255, 170, 60), -- orange accent band on cover
        Bark = Color3.fromRGB(150, 95, 60),
        Needles = { Color3.fromRGB(60, 200, 110), Color3.fromRGB(40, 175, 120), Color3.fromRGB(90, 215, 90) },
        Wood = Color3.fromRGB(200, 130, 70),
        Marker = Color3.fromRGB(255, 240, 80), -- neon lane strips
        Mountain = Color3.fromRGB(120, 150, 210), -- distant blue silhouettes
    },

    Terrain = {
        GroundMaterial = Enum.Material.Grass,
        GroundColor = Color3.fromRGB(96, 190, 96), -- bright toy grass
        -- Rolling hills inside the arena: {x, y, z, radius}. Kept low so they act as cover, not walls.
        Hills = {
            { -30, -6, -62, 22 },
            { 30, -6, -62, 22 },
            { -30, -6, 62, 22 },
            { 30, -6, 62, 22 },
            { -78, -4, 0, 18 },
            { 78, -4, 0, 18 },
        },
        -- Mountain backdrop outside the play area (seen in the distance like the third photo)
        Mountains = {
            { 0, -40, -330, 140 },
            { -160, -60, -300, 110 },
            { 170, -50, -290, 120 },
            { 0, -30, 330, 120 },
            { -190, -50, 300, 100 },
            { 200, -55, 300, 110 },
        },
        -- Shallow lake in the middle: {x, z, radiusX, radiusZ, depth}
        Lake = { 0, 0, 22, 14, 3 },
    },

    -- Center-line cover: boulders around the lake and a fallen log bridge
    Center = {
        { kind = "rock", pos = { 0, 0, -26 }, size = { 12, 6, 7 } },
        { kind = "rock", pos = { 0, 0, 26 }, size = { 12, 6, 7 } },
        { kind = "log", pos = { 0, 1, 0 }, size = { 4, 2.5, 34 }, rot = { 0, 0, 0 } },
    },

    -- Red-side cover (mirrored for Blue)
    Mirrored = {
        -- rocky outcrop = sniper perch, in each side lane
        { kind = "rock", pos = { -42, 0, -58 }, size = { 18, 9, 14 } },
        { kind = "rock", pos = { -42, 0, 58 }, size = { 18, 9, 14 } },
        { kind = "rock", pos = { -30, 0, -62 }, size = { 10, 4.5, 8 } }, -- step up to perch
        { kind = "rock", pos = { -30, 0, 62 }, size = { 10, 4.5, 8 } },

        -- mid lane cover
        { kind = "rock", pos = { -66, 0, 0 }, size = { 8, 4.5, 6 } },
        { kind = "log", pos = { -50, 1, -8 }, size = { 3, 2.5, 12 }, rot = { 0, 20, 0 } },
        { kind = "log", pos = { -50, 1, 8 }, size = { 3, 2.5, 12 }, rot = { 0, -20, 0 } },
        { kind = "rock", pos = { -30, 0, 0 }, size = { 7, 5, 7 } },
        { kind = "stump", pos = { -18, 0, -16 }, size = { 5, 3, 5 } },
        { kind = "stump", pos = { -18, 0, 16 }, size = { 5, 3, 5 } },

        -- side lane cover
        { kind = "log", pos = { -22, 1, -40 }, size = { 3, 2.5, 14 }, rot = { 0, 80, 0 } },
        { kind = "log", pos = { -22, 1, 40 }, size = { 3, 2.5, 14 }, rot = { 0, -80, 0 } },
        { kind = "rock", pos = { -62, 0, -48 }, size = { 6, 4.5, 10 } },
        { kind = "rock", pos = { -62, 0, 48 }, size = { 6, 4.5, 10 } },

        -- glowing lane strips (mirrored) so routes read at a glance
        { kind = "marker", pos = { -70, 0, 0 }, size = { 40, 0.3, 1.5 } },
        { kind = "marker", pos = { -40, 0, -50 }, size = { 30, 0.3, 1.5 }, rot = { 0, 25, 0 } },
        { kind = "marker", pos = { -40, 0, 50 }, size = { 30, 0.3, 1.5 }, rot = { 0, -25, 0 } },

        -- dense tree clusters that block long sightlines out of spawn
        { kind = "grove", pos = { -80, 0, -40 }, size = { 24, 0, 24 }, count = 9 },
        { kind = "grove", pos = { -80, 0, 40 }, size = { 24, 0, 24 }, count = 9 },
    },

    -- Scatter trees everywhere except lanes and spawns
    Trees = {
        Count = 90,
        MinSpacing = 13,
        -- Rectangles kept clear: {x, z, halfW, halfD}
        Exclude = {
            { 0, 0, 40, 40 }, -- lake and mid
            { -100, 0, 20, 30 }, -- Red spawn
            { 100, 0, 20, 30 }, -- Blue spawn
            { -50, 0, 30, 12 }, -- Red mid lane
            { 50, 0, 30, 12 }, -- Blue mid lane
        },
        Height = { 24, 40 },
    },
}
