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

    -- Matchmaking pads. Each has a Red half and a Blue half; stand on a half to queue for
    -- that mode on that team. Green ring = 1v1, blue ring = 2v2. Size is the whole pad.
    Pads = {
        -- FEATURED: Convergence, 6v6 objective battle (starts at 4v4 after a wait). Big, central, gold-framed.
        {
            name = "PadConvergence",
            kind = "Convergence",
            mode = "CONVERGENCE",
            featured = true,
            teamSize = 6, -- overridden at build time by Convergence_TeamSize / MinTeamSize in Tuning
            minTeamSize = 4,
            pos = { 0, 0, -18 },
            size = { 44, 1, 22 },
            color = Color3.fromRGB(255, 200, 70),
        },
        -- Duel: elimination, smaller side pads
        {
            name = "Pad1v1",
            kind = "Duel",
            mode = "DUEL 1v1",
            teamSize = 1,
            pos = { -44, 0, -24 },
            size = { 16, 1, 12 },
            color = Color3.fromRGB(80, 230, 120),
        },
        {
            name = "Pad2v2",
            kind = "Duel",
            mode = "DUEL 2v2",
            teamSize = 2,
            pos = { 44, 0, -24 },
            size = { 16, 1, 12 },
            color = Color3.fromRGB(80, 150, 255),
        },
    },

    -- Leaderboard wall (opposite the kiosk): Rating, Best Streak, Wins, Bounties Claimed
    Board = { pos = { 44, 0, 12 }, size = { 22, 10, 1 } },

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
