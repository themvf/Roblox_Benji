-- Greybox arena layout, mirrored across the X axis so both teams get the same geometry.
-- Coordinates are {x, y, z} in studs. Every entry in Mirrored is duplicated with x flipped.
-- Edit numbers here and Rojo pushes the new map to Studio instantly.
return {
    Name = "Greybox",
    Size = 220, -- floor is Size x Size, centered at origin
    WallHeight = 24,

    -- Red spawns at -X, Blue at +X. Facing is toward the center.
    Spawns = {
        Red = { { -95, 3, -12 }, { -95, 3, 0 }, { -95, 3, 12 }, { -100, 3, -6 }, { -100, 3, 6 }, { -98, 3, 18 } },
        Blue = { { 95, 3, -12 }, { 95, 3, 0 }, { 95, 3, 12 }, { 100, 3, -6 }, { 100, 3, 6 }, { 98, 3, 18 } },
    },

    Objectives = {
        { Name = "North", pos = { 0, 0, -45 }, radius = 12, Phases = { 1 } },
        { Name = "South", pos = { 0, 0, 45 }, radius = 12, Phases = { 1, 2 } },
        { Name = "Mid", pos = { 0, 4, 0 }, radius = 14, Phases = { 1, 2, 3 } },
    },

    -- Pieces placed once, on the center line.
    Center = {
        { name = "MidPlatform", pos = { 0, 2, 0 }, size = { 24, 4, 24 } },
        { name = "MidPillarN", pos = { 0, 6, -30 }, size = { 6, 12, 6 } },
        { name = "MidPillarS", pos = { 0, 6, 30 }, size = { 6, 12, 6 } },
        { name = "MidCoverN", pos = { 0, 2, -14 }, size = { 12, 4, 2 } },
        { name = "MidCoverS", pos = { 0, 2, 14 }, size = { 12, 4, 2 } },
    },

    -- Pieces placed at x and again at -x. Give the Red-side (negative x) coordinates.
    Mirrored = {
        -- Spawn room walls (open toward center)
        { name = "SpawnBack", pos = { -105, 8, 0 }, size = { 2, 16, 50 } },
        { name = "SpawnSideN", pos = { -90, 8, -25 }, size = { 32, 16, 2 } },
        { name = "SpawnSideS", pos = { -90, 8, 25 }, size = { 32, 16, 2 } },

        -- Lane dividers create three lanes: north, mid, south
        { name = "LaneWallN", pos = { -45, 6, -22 }, size = { 30, 12, 2 } },
        { name = "LaneWallS", pos = { -45, 6, 22 }, size = { 30, 12, 2 } },

        -- Waist-high cover, spaced 10-15 studs
        { name = "Cover1", pos = { -65, 2, 0 }, size = { 8, 4, 2 } },
        { name = "Cover2", pos = { -50, 2, -8 }, size = { 2, 4, 8 } },
        { name = "Cover3", pos = { -50, 2, 8 }, size = { 2, 4, 8 } },
        { name = "Cover4", pos = { -30, 2, 0 }, size = { 6, 4, 6 } },
        { name = "Cover5", pos = { -22, 2, -40 }, size = { 10, 4, 2 } },
        { name = "Cover6", pos = { -22, 2, 40 }, size = { 10, 4, 2 } },
        { name = "Cover7", pos = { -60, 2, -50 }, size = { 2, 4, 10 } },
        { name = "Cover8", pos = { -60, 2, 50 }, size = { 2, 4, 10 } },

        -- Sniper perch with ramp, in each side lane
        { name = "PerchN", pos = { -40, 6, -55 }, size = { 16, 1, 16 } },
        { name = "PerchNRamp", pos = { -26, 3, -55 }, size = { 12, 1, 8 }, rot = { 0, 0, -27 } },
        { name = "PerchNRail", pos = { -40, 8.5, -47.5 }, size = { 16, 4, 1 } },
        { name = "PerchS", pos = { -40, 6, 55 }, size = { 16, 1, 16 } },
        { name = "PerchSRamp", pos = { -26, 3, 55 }, size = { 12, 1, 8 }, rot = { 0, 0, -27 } },
        { name = "PerchSRail", pos = { -40, 8.5, 47.5 }, size = { 16, 4, 1 } },

        -- Corner blocks so side lanes are not one straight sightline
        { name = "CornerBlockN", pos = { -75, 6, -75 }, size = { 20, 12, 20 } },
        { name = "CornerBlockS", pos = { -75, 6, 75 }, size = { 20, 12, 20 } },
    },
}
