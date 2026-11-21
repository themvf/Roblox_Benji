-- Faction Islands (approved 2026-11-20, docs/design/lobby-experience/hub-concept/factions.py).
--
-- The lobby is a Hold: a neutral spine of floating islands over the void, with one island per
-- faction off it, each built in its own style and lit in its own colour.
--   Arrival island  spawns, the departures board, the season canister; faces the pads (-z).
--   Pad island      the mode pads, straight ahead over the first bridge.
--   Gate island     Convergence under the PLAY gate, beyond the pads.
--   ARMORY          Forge Union, front left, with the loadout kiosk.
--   ALTER EGO       Coherence Institute, front right.
--   SHOP            Kade Dynamics, back right; signposted only until the store exists.
--   THE LEDGER      the Ferrymen, back left: the leaderboards.
--
-- The marker positions below match assets/environment/source/Lobby.rbxm, which
-- tools/lobbyauthor/faction_islands.luau builds. Pieces is the old hall, used only if
-- no editable or saved lobby model exists.
--
-- Colour rules: structure is dark and desaturated, saturation is reserved for meaning. Amber =
-- interact / CTA. Red and blue = team, nothing else. Each faction's colour appears only on its
-- own island and bridge.
return {
    Origin = { 0, 400, 900 },
    Size = { 150, 130 }, -- the fallback hall only; the islands' Floor is an invisible marker footprint

    Palette = {
        Floor = Color3.fromRGB(46, 50, 60),
        FloorGrid = Color3.fromRGB(34, 37, 45),
        Wall = Color3.fromRGB(38, 42, 52),
        Accent = Color3.fromRGB(255, 196, 70), -- interact / CTA only
        Pillar = Color3.fromRGB(64, 70, 84),
        Gate = Color3.fromRGB(72, 80, 96),
        Armory = Color3.fromRGB(58, 66, 80),
        Ego = Color3.fromRGB(78, 54, 96),
        -- the four sides; each colour is used on its own island only
        Forge = Color3.fromRGB(255, 92, 31),
        Institute = Color3.fromRGB(128, 224, 255),
        Kade = Color3.fromRGB(255, 204, 97),
        Ferry = Color3.fromRGB(158, 255, 64),
    },

    Spawns = {
        { 0, 3, 30 },
        { -7, 3, 32 },
        { 7, 3, 32 },
        { -14, 3, 34 },
        { 14, 3, 34 },
    },

    -- Anyone outside a match who ends up in this box (lobby coordinates) has fallen off an
    -- island; MapService puts them back on an arrival spawn. The islands' tops are at y 0.
    FallRecovery = { min = { -260, -260, -340 }, max = { 260, -40, 190 } },

    -- Cool ankle-height mist across the central arrival area. The emitters are
    -- placed by MapService for both the editable and baked lobby.
    ArrivalMist = {
        Center = { 0, 0.28, 32 },
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
            teamSize = 5,
            minTeamSize = 3,
            pos = { 0, 0, -218 }, -- gate island, under the PLAY gate
            size = { 36, 1, 18 },
            color = Color3.fromRGB(255, 196, 70),
        },
        {
            name = "Pad1v1",
            kind = "Duel",
            mode = "DUEL 1v1",
            teamSize = 1,
            pos = { -22, 0, -92 }, -- pad island, front left
            size = { 25, 1, 9 },
            color = Color3.fromRGB(120, 200, 160),
        },
        {
            name = "Pad2v2",
            kind = "Duel",
            mode = "DUEL 2v2",
            disabled = true, -- Duel is 1v1 only; keep marker definition so LobbyAuthoring stays valid
            teamSize = 2,
            pos = { -22, 0, -113 }, -- not drawn while disabled
            size = { 25, 1, 9 },
            color = Color3.fromRGB(120, 200, 160),
        },
        {
            name = "PadTDM",
            kind = "TDM",
            mode = "TEAM DEATHMATCH",
            teamSize = 5,
            minTeamSize = 2,
            pos = { 22, 0, -92 }, -- pad island, front right
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
            pos = { -22, 0, -134 },
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
            pos = { 22, 0, -134 },
            size = { 16, 1, 9 },
            color = Color3.fromRGB(170, 140, 235),
        },
    },

    -- Stations turn to face the arrival island (yaw in degrees; the sign is on the -Z face).
    -- The leaderboard is the Ferrymen's Ledger, on their island's back wall.
    Board = { pos = { -172.46, 2, 124.28 }, size = { 30, 12, 1 }, yaw = 298.66 },

    -- The loadout kiosk stands at the Forge Union's counter.
    Kiosk = {
        pos = { -147, 0, -99.36 },
        size = { 12, 3.5, 5 },
        yaw = 228.65,
        showcase = "AssaultRifle",
    },

    -- The islands name themselves in surface lettering facing the arrival island. The one
    -- billboard marks the way into the pads, where the first view from every spawn points.
    Wayfinding = {
        {
            name = "Play",
            pos = { 0, 18, -60 }, -- over the pad island end of the first bridge
            size = { 40, 7 },
            title = "PLAY",
            detail = "DUELS  |  CONVERGENCE  |  TDM",
            color = "Accent",
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

    -- One light per destination, in that destination's colour.
    Lights = {
        { name = "GateLight", pos = { 0, 40, -235 }, color = "Accent", range = 90, brightness = 2 },
        { name = "ArmoryLight", pos = { -150, 26, -102 }, color = "Forge", range = 70, brightness = 2 },
        { name = "TdmLight", pos = { 0, 22, -112 }, color = "Accent", range = 80, brightness = 1.2 },
        { name = "EgoLight", pos = { 150, 26, -102 }, color = "Institute", range = 70, brightness = 2 },
        { name = "BoardLight", pos = { -150, 26, 112 }, color = "Ferry", range = 70, brightness = 1.6 },
    },
}
