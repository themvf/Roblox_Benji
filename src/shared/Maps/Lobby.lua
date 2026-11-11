-- Combat staging hub. Not a queue room with pads scattered across the floor.
--
-- The central rectangular PLAY hall is the dominant destination. Its mode
-- zones are visible from arrival: Duel, Convergence, Team Deathmatch, Training.
--   ARMORY    left bay, weapon displays and the loadout station.
--   ALTER EGO right bay, deliberately stranger. Titan/Colossus is the differentiating
--             mechanic and previously had no physical presence in the lobby at all.
--
-- Colour rules, carried over from Snow Fortress: structure is dark and desaturated, saturation
-- is reserved for meaning. Amber = interact / CTA. Red and blue = team, nothing else. The old
-- lobby was near-white (235,232,225) which blew out and made every pad look fluorescent.
return {
    Origin = { 0, 400, 900 },
    Size = { 150, 130 }, -- must cover the gate at z -56 and the back wall at z 64

    Palette = {
        Floor = Color3.fromRGB(46, 50, 60),
        FloorGrid = Color3.fromRGB(34, 37, 45),
        Wall = Color3.fromRGB(38, 42, 52),
        Accent = Color3.fromRGB(255, 196, 70), -- interact / CTA only
        Pillar = Color3.fromRGB(64, 70, 84),
        Gate = Color3.fromRGB(72, 80, 96),
        Armory = Color3.fromRGB(58, 66, 80),
        Ego = Color3.fromRGB(78, 54, 96), -- the one strange colour in the room
    },

    Spawns = {
        { 0, 3, 10 },
        { -7, 3, 12 },
        { 7, 3, 12 },
        { -14, 3, 14 },
        { 14, 3, 14 },
    },

    -- Cool ankle-height mist across the central arrival area. The emitters are
    -- placed by MapService for both the editable and baked lobby.
    ArrivalMist = {
        Center = { 0, 0.28, 12 },
        Columns = 5,
        Rows = 3,
        Spacing = { 7, 6 },
        RatePerEmitter = 5,
        Texture = "rbxasset://textures/particles/smoke_main.dds",
    },

    -- Distinct mode zones inside one rectangular PLAY hall. The TDM halves each
    -- fit five standing players without crossing into Convergence or the exit.
    Pads = {
        {
            name = "PadConvergence",
            kind = "Convergence",
            mode = "CONVERGENCE",
            featured = true,
            teamSize = 6,
            minTeamSize = 4,
            pos = { 0, 0, -32 },
            size = { 36, 1, 18 },
            color = Color3.fromRGB(255, 196, 70),
        },
        {
            name = "Pad1v1",
            kind = "Duel",
            mode = "DUEL 1v1",
            teamSize = 1,
            pos = { -47, 0, -28 },
            size = { 25, 1, 9 },
            color = Color3.fromRGB(120, 200, 160),
        },
        {
            name = "Pad2v2",
            kind = "Duel",
            mode = "DUEL 2v2",
            teamSize = 2,
            pos = { -47, 0, -43 },
            size = { 25, 1, 9 },
            color = Color3.fromRGB(120, 200, 160),
        },
        {
            name = "PadTDM",
            kind = "TDM",
            mode = "TEAM DEATHMATCH",
            teamSize = 5,
            minTeamSize = 5,
            pos = { 44, 0, -34 },
            size = { 34, 1, 22 },
            color = Color3.fromRGB(255, 196, 70),
        },
        -- Its own corner of the room, opposite the kiosk, because it is not a way to
        -- play the game -- it is the way to go look at a map you are building.
        --
        -- Every other pad needs both sides populated before it can start, so one person
        -- alone can never leave the lobby: Red or Blue is always zero. `solo` starts on
        -- a single occupant and skips the fill wait entirely. The map vote still opens,
        -- with one voter, which is how you choose where you are going.
        --
        -- Training: one player, bots on both sides, filled to Config.Training.TeamSize
        -- per team, so the player's side has one bot fewer. One pad per mode.
        {
            name = "PadTrainingObjective",
            kind = "Convergence",
            mode = "TRAINING · OBJECTIVE",
            solo = true,
            teamSize = 1,
            minTeamSize = 1,
            pos = { -10, 0, -51 },
            size = { 16, 1, 9 },
            color = Color3.fromRGB(170, 140, 235),
        },
        {
            name = "PadTrainingTDM",
            kind = "TDM",
            mode = "TRAINING · TDM",
            solo = true,
            teamSize = 1,
            minTeamSize = 1,
            pos = { 10, 0, -51 },
            size = { 16, 1, 9 },
            color = Color3.fromRGB(170, 140, 235),
        },
    },

    Board = { pos = { 0, 0, 52 }, size = { 26, 9, 1 } },

    Kiosk = {
        pos = { -52, 0, 6 },
        size = { 12, 3.5, 5 },
        showcase = "AssaultRifle",
    },

    -- The first view from every spawn points at PLAY. These labels name the
    -- destinations before a player reaches the smaller mode pads or stations.
    Wayfinding = {
        {
            name = "Play",
            pos = { 0, 27, -13 },
            size = { 28, 5 },
            title = "PLAY",
            detail = "DUELS  |  CONVERGENCE  |  TDM",
            color = "Accent",
        },
        {
            name = "Armory",
            pos = { -52, 15, 6 },
            size = { 13, 3.5 },
            title = "ARMORY",
            detail = "LOADOUT",
            color = "Accent",
        },
        {
            name = "AlterEgo",
            pos = { 52, 15, 6 },
            size = { 15, 3.5 },
            title = "ALTER EGO",
            detail = "CHOOSE YOUR FORM",
            color = "Ego",
        },
    },

    Pieces = {
        -- ===== floor plates: each destination stands on its own, so the eye reads three places =====
        { name = "PlatePlay", pos = { 0, 0.3, -36 }, size = { 132, 0.4, 44 }, color = "FloorGrid" },
        { name = "PlateArmory", pos = { -52, 0.3, 6 }, size = { 30, 0.4, 34 }, color = "FloorGrid" },
        { name = "PlateEgo", pos = { 52, 0.3, 6 }, size = { 30, 0.4, 34 }, color = "FloorGrid" },

        -- Low path lights link the five arrival spawns to the PLAY hall. They stop
        -- before its floor plate and do not change collision or queue volumes.
        { name = "PlayPathL", pos = { -18, 0.05, 16 }, size = { 0.35, 0.04, 56 }, color = "Accent", collide = false },
        { name = "PlayPathR", pos = { 18, 0.05, 16 }, size = { 0.35, 0.04, 56 }, color = "Accent", collide = false },

        -- ===== PLAY: a broad rectangular frame around all four mode zones =====
        { name = "PlayPillarL", pos = { -64, 12, -14 }, size = { 4, 24, 4 }, color = "Gate" },
        { name = "PlayPillarR", pos = { 64, 12, -14 }, size = { 4, 24, 4 }, color = "Gate" },
        { name = "PlayHeader", pos = { 0, 25, -14 }, size = { 132, 5, 4 }, color = "Gate" },
        { name = "PlayHeaderGlow", pos = { 0, 22.3, -11.8 }, size = { 128, 0.5, 0.8 }, color = "Accent" },
        { name = "PlayBack", pos = { 0, 8, -61 }, size = { 132, 16, 2 }, color = "Wall" },
        { name = "PlaySideL", pos = { -65, 4, -39 }, size = { 2, 8, 44 }, color = "Wall" },
        { name = "PlaySideR", pos = { 65, 4, -39 }, size = { 2, 8, 44 }, color = "Wall" },

        -- ===== ARMORY: a bay you walk into, with a rack behind the counter =====
        { name = "ArmoryBack", pos = { -64, 9, 6 }, size = { 3, 18, 34 }, color = "Armory" },
        { name = "ArmorySideN", pos = { -52, 9, -10 }, size = { 27, 18, 3 }, color = "Armory" },
        { name = "ArmorySideS", pos = { -52, 9, 22 }, size = { 27, 18, 3 }, color = "Armory" },
        { name = "ArmoryRoof", pos = { -52, 18.5, 6 }, size = { 30, 1, 34 }, color = "Wall" },
        { name = "ArmoryGlow", pos = { -52, 17.6, 6 }, size = { 22, 0.4, 0.8 }, color = "Accent" },
        { name = "ArmoryRack", pos = { -62, 6, 6 }, size = { 1.5, 8, 24 }, color = "Pillar" },

        -- ===== ALTER EGO: same footprint, deliberately not the same feeling =====
        { name = "EgoBack", pos = { 64, 9, 6 }, size = { 3, 18, 34 }, color = "Ego" },
        { name = "EgoSideN", pos = { 52, 9, -10 }, size = { 27, 18, 3 }, color = "Ego" },
        { name = "EgoSideS", pos = { 52, 9, 22 }, size = { 27, 18, 3 }, color = "Ego" },
        { name = "EgoRoofL", pos = { 52, 18.5, -2 }, size = { 30, 1, 14 }, color = "Wall" },
        { name = "EgoRoofR", pos = { 52, 18.5, 14 }, size = { 30, 1, 14 }, color = "Wall" },
        -- the roof is split: the chamber is open to the sky over the plinth
        { name = "EgoPlinth", pos = { 52, 2, 6 }, size = { 10, 4, 10 }, color = "Pillar" },
        { name = "EgoPlinthTop", pos = { 52, 4.2, 6 }, size = { 11, 0.4, 11 }, color = "Ego" },
        { name = "EgoRingN", pos = { 52, 0.6, -2 }, size = { 18, 0.5, 0.8 }, color = "Ego" },
        { name = "EgoRingS", pos = { 52, 0.6, 14 }, size = { 18, 0.5, 0.8 }, color = "Ego" },

        -- ===== perimeter: low and dark, so nothing competes with the three destinations =====
        { name = "WallBack", pos = { 0, 7, 64 }, size = { 140, 14, 2 }, color = "Wall" },
        { name = "WallL", pos = { -69, 7, 6 }, size = { 2, 14, 118 }, color = "Wall" },
        { name = "WallR", pos = { 69, 7, 6 }, size = { 2, 14, 118 }, color = "Wall" },
    },

    -- Controlled accent lighting instead of a blown-out white floor. One light per destination,
    -- so the room reads as three beacons in a dark hall.
    Lights = {
        { name = "GateLight", pos = { 0, 22, -32 }, color = "Accent", range = 65, brightness = 2 },
        { name = "ArmoryLight", pos = { -52, 15, 6 }, color = "Accent", range = 30, brightness = 1.4 },
        { name = "TdmLight", pos = { 44, 13, -34 }, color = "Accent", range = 24, brightness = 1.2 },
        { name = "EgoLight", pos = { 52, 12, 6 }, color = "Ego", range = 32, brightness = 2.2 },
        { name = "BoardLight", pos = { 0, 12, 48 }, color = "Pillar", range = 26, brightness = 1 },
    },
}
