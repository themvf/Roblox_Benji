-- Combat staging hub. Not a queue room with pads scattered across the floor.
--
-- Three destinations, in deliberate order of visual weight:
--   PLAY      the arena gate, dead centre, the tallest thing in the room. Mode pads live
--             INSIDE it, so they are something you find after choosing to play rather than
--             the room's visual content.
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
        { 0, 3, 42 },
        { -8, 3, 44 },
        { 8, 3, 44 },
        { -16, 3, 46 },
        { 16, 3, 46 },
    },

    -- Pads sit inside the gate mouth, not out on the open floor. Convergence is centred under
    -- the arch; the two Duel pads are tucked behind it, smaller, and read as secondary.
    Pads = {
        {
            name = "PadConvergence",
            kind = "Convergence",
            mode = "CONVERGENCE",
            featured = true,
            teamSize = 6,
            minTeamSize = 4,
            pos = { 0, 0, -30 },
            size = { 36, 1, 18 },
            color = Color3.fromRGB(255, 196, 70),
        },
        {
            name = "Pad1v1",
            kind = "Duel",
            mode = "DUEL 1v1",
            teamSize = 1,
            pos = { -26, 0, -46 },
            size = { 12, 1, 10 },
            color = Color3.fromRGB(120, 200, 160),
        },
        {
            name = "Pad2v2",
            kind = "Duel",
            mode = "DUEL 2v2",
            teamSize = 2,
            pos = { 26, 0, -46 },
            size = { 12, 1, 10 },
            color = Color3.fromRGB(120, 200, 160),
        },
    },

    Board = { pos = { 0, 0, 52 }, size = { 26, 9, 1 } },

    Kiosk = {
        pos = { -52, 0, 6 },
        size = { 12, 3.5, 5 },
        showcase = "AssaultRifle",
    },

    Pieces = {
        -- ===== floor plates: each destination stands on its own, so the eye reads three places =====
        { name = "PlateGate", pos = { 0, 0.3, -34 }, size = { 70, 0.4, 44 }, color = "FloorGrid" },
        { name = "PlateArmory", pos = { -52, 0.3, 6 }, size = { 30, 0.4, 34 }, color = "FloorGrid" },
        { name = "PlateEgo", pos = { 52, 0.3, 6 }, size = { 30, 0.4, 34 }, color = "FloorGrid" },

        -- ===== PLAY: the arena gate. Tallest mass in the room, framing the pads =====
        { name = "GateLegL", pos = { -30, 14, -30 }, size = { 6, 28, 16 }, color = "Gate" },
        { name = "GateLegR", pos = { 30, 14, -30 }, size = { 6, 28, 16 }, color = "Gate" },
        { name = "GateLintel", pos = { 0, 29, -30 }, size = { 66, 6, 16 }, color = "Gate" },
        { name = "GateCrown", pos = { 0, 33, -30 }, size = { 54, 2, 12 }, color = "Pillar" },
        -- amber lip along the underside of the arch: the room's brightest accent, and it points in
        { name = "GateGlow", pos = { 0, 25.6, -22.4 }, size = { 60, 0.5, 0.8 }, color = "Accent" },
        { name = "GateBackL", pos = { -20, 10, -52 }, size = { 22, 20, 3 }, color = "Wall" },
        { name = "GateBackR", pos = { 20, 10, -52 }, size = { 22, 20, 3 }, color = "Wall" },

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
        { name = "GateLight", pos = { 0, 22, -30 }, color = "Accent", range = 46, brightness = 2 },
        { name = "ArmoryLight", pos = { -52, 15, 6 }, color = "Accent", range = 30, brightness = 1.4 },
        { name = "EgoLight", pos = { 52, 12, 6 }, color = "Ego", range = 32, brightness = 2.2 },
        { name = "BoardLight", pos = { 0, 12, 48 }, color = "Pillar", range = 26, brightness = 1 },
    },
}
