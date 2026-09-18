-- Lobby hub: a floating platform far above the arena. Players spawn here,
-- walk onto a glowing pad to queue, and get moved to the arena when a match starts.
-- Positions are relative to Origin. Same palette rules as the maps:
-- soft environment, loud emissive interaction points, team colors reserved.
return {
    Origin = { 0, 400, 900 },
    Size = { 120, 90 }, -- platform width (x) and depth (z)

    Palette = {
        Floor = Color3.fromRGB(235, 232, 225),
        FloorGrid = Color3.fromRGB(210, 206, 198),
        Wall = Color3.fromRGB(120, 170, 235),
        Accent = Color3.fromRGB(255, 200, 70),
        Pillar = Color3.fromRGB(250, 250, 250),
    },

    -- Where players stand when they load in or come back from a match
    Spawns = {
        { 0, 3, 30 },
        { -8, 3, 32 },
        { 8, 3, 32 },
        { -16, 3, 34 },
        { 16, 3, 34 },
    },

    -- Matchmaking pads. Stand on one to queue. Green = 1v1, blue = 2v2.
    Pads = {
        {
            name = "Pad1v1",
            mode = "1v1",
            teamSize = 1,
            pos = { -22, 0, -10 },
            size = { 16, 1, 16 },
            color = Color3.fromRGB(80, 230, 120),
        },
        {
            name = "Pad2v2",
            mode = "2v2",
            teamSize = 2,
            pos = { 22, 0, -10 },
            size = { 16, 1, 16 },
            color = Color3.fromRGB(80, 150, 255),
        },
    },

    -- Weapon kiosk: walk up and press E to open the loadout picker
    Kiosk = {
        pos = { -44, 0, 12 }, -- counter center, on the floor
        size = { 12, 3.5, 5 },
        showcase = "AssaultRifle", -- model displayed on the counter
    },

    -- Decorative structure so the hub reads as a place, not a slab
    Pieces = {
        { name = "BackWall", pos = { 0, 6, -44 }, size = { 120, 12, 2 }, color = "Wall" },
        { name = "LeftWall", pos = { -59, 6, 0 }, size = { 2, 12, 90 }, color = "Wall" },
        { name = "RightWall", pos = { 59, 6, 0 }, size = { 2, 12, 90 }, color = "Wall" },
        { name = "PillarL", pos = { -40, 8, -30 }, size = { 4, 16, 4 }, color = "Pillar" },
        { name = "PillarR", pos = { 40, 8, -30 }, size = { 4, 16, 4 }, color = "Pillar" },
        { name = "Banner", pos = { 0, 13, -43 }, size = { 60, 6, 1 }, color = "Accent" },
        { name = "Step", pos = { 0, 0.5, 10 }, size = { 80, 1, 10 }, color = "FloorGrid" },
    },
}
