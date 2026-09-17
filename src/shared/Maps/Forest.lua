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
        Red = { { -100, 4, -14 }, { -100, 4, 0 }, { -100, 4, 14 } },
        Blue = { { 100, 4, -14 }, { 100, 4, 0 }, { 100, 4, 14 } },
    },

    Environment = {
        ClockTime = 17.6, -- golden hour
        Brightness = 1.6,
        Ambient = Color3.fromRGB(70, 85, 75),
        OutdoorAmbient = Color3.fromRGB(110, 125, 105),
        FogColor = Color3.fromRGB(205, 195, 175),
        FogStart = 40,
        FogEnd = 320,
        Atmosphere = { Density = 0.42, Haze = 2.4, Glare = 0.35, Color = Color3.fromRGB(215, 200, 180) },
        SunRays = 0.18,
        Bloom = 0.35,
    },

    Terrain = {
        GroundMaterial = Enum.Material.Grass,
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

        -- dense tree clusters that block long sightlines out of spawn
        { kind = "grove", pos = { -80, 0, -40 }, size = { 24, 0, 24 }, count = 9 },
        { kind = "grove", pos = { -80, 0, 40 }, size = { 24, 0, 24 }, count = 9 },
    },

    -- Scatter trees everywhere except lanes and spawns
    Trees = {
        Count = 150,
        MinSpacing = 9,
        -- Rectangles kept clear: {x, z, halfW, halfD}
        Exclude = {
            { 0, 0, 40, 40 }, -- lake and mid
            { -100, 0, 20, 30 }, -- Red spawn
            { 100, 0, 20, 30 }, -- Blue spawn
            { -50, 0, 30, 12 }, -- Red mid lane
            { 50, 0, 30, 12 }, -- Blue mid lane
        },
        Height = { 26, 46 },
    },
}
