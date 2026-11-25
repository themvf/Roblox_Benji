-- Choke Ridge: sculpted, almost-fully-natural Middle Eastern sandstone canyon T-spur map.
-- Zero water, zero terrain balls: clean canyon chasm void framed by stratified sandstone cliffs,
-- angled WedgePart rock slopes, vaulted cave arches, leaning cover monoliths, and distant mesas.
--
-- Gameplay:
--   - North sheer mountain wall seals the back of the map; central ridge spur juts south over the abyss.
--   - Ground combat is forced THROUGH the cave tunnel (CQC) or AROUND the narrow southern nose (precipice).
--   - Ridge crest above the cave (Y = 16..74) is unwalkable on foot; Jetpack pickups/kits can fly over top.
--   - Anti-sniper cover: spawn shield fins, sunken gulch parapet wall, leaning cave-mouth guard boulders,
--     rock-to-rock nose cover beats, and split sniper shelves divided by rock horns.

local Center = {}
local Mirrored = {}

local STRATA = {
    { color = "StrataDark", material = "Basalt" },
    { color = "StrataSienna", material = "Basalt" },
    { color = "StrataRust", material = "Sandstone" },
    { color = "StrataOchre", material = "Sandstone" },
    { color = "StrataPale", material = "Limestone" },
}

local function add(list, piece)
    table.insert(list, piece)
end

-- Horizontal sedimentary sandstone bands + optional sloped cap/buttress wedges around a cliff mass.
local function addStrataStack(list, prefix, x, z, yBot, yTop, w, d, layers, decor, overhang)
    local hTotal = yTop - yBot
    local layerH = hTotal / layers
    local stepOut = overhang or 1.8
    for i = 1, layers do
        local st = STRATA[((i - 1) % #STRATA) + 1]
        local cy = yBot + (i - 0.5) * layerH
        -- Subtle alternating shelf ledges so vertical walls break into natural horizontal strata
        local swell = ((i % 3) == 0 and stepOut) or ((i % 2) == 0 and -stepOut * 0.4) or 0
        add(list, {
            kind = "block",
            name = prefix .. "_L" .. i,
            pos = { x, cy, z },
            size = { w + swell, layerH + 0.15, d + swell },
            color = st.color,
            material = st.material,
            decor = decor,
        })
    end
end

-- Sculpted cliff skirt descending into the canyon abyss beneath any playable mesa/ledge.
local function addCliffSkirt(list, prefix, x, z, yTop, w, d, depth)
    addStrataStack(list, prefix, x, z, yTop - depth, yTop - 1.2, w, d, 7, true, 3.2)
    -- Sloped talus wedge skirts along the upper rim so edges read as eroded rock, not flat boxes
    add(list, {
        kind = "block",
        name = prefix .. "_RimCap",
        pos = { x, yTop - 1.15, z },
        size = { w + 1.2, 2.0, d + 1.2 },
        color = "StrataPale",
        material = "Limestone",
        decor = true,
    })
end

-- Multi-part sculpted sandstone boulder/monolith: solid core + solid angled facets for honest cover.
local function addMonolith(list, prefix, x, y, z, sx, sy, sz, yaw, solid)
    add(list, {
        kind = "block",
        name = prefix .. "_Core",
        pos = { x, y + sy * 0.46, z },
        size = { sx, sy * 0.92, sz },
        rot = { 0, yaw or 0, 0 },
        color = "Boulder",
        material = "Slate",
        decor = not solid,
    })
    -- Slanted shoulder wedge on one side (collides honestly when solid = true)
    add(list, {
        kind = "block",
        shape = "Wedge",
        name = prefix .. "_SlopeA",
        pos = { x + sx * 0.28, y + sy * 0.45, z },
        size = { sz * 0.88, sy * 0.9, sx * 0.55 },
        rot = { 0, (yaw or 0) + 90, 0 },
        color = "StrataOchre",
        material = "Sandstone",
        decor = not solid,
    })
    -- Opposite jagged cap wedge (collides honestly when solid = true)
    add(list, {
        kind = "block",
        shape = "Wedge",
        name = prefix .. "_CapWedge",
        pos = { x - sx * 0.12, y + sy * 0.94, z },
        size = { sx * 0.72, sy * 0.34, sz * 0.74 },
        rot = { 0, (yaw or 0) + 180, 0 },
        color = "StrataPale",
        material = "Limestone",
        decor = not solid,
    })
    -- Base pebble rubble collar
    add(list, {
        kind = "block",
        name = prefix .. "_BaseRubble",
        pos = { x, y + 0.55, z },
        size = { sx * 1.14, 1.1, sz * 1.14 },
        rot = { 0, (yaw or 0) + 12, 0 },
        color = "StrataRust",
        material = "Pebble",
        decor = true,
    })
end

-- Vaulted natural sandstone cave arch rib (haunch wedges + brow overhang + hanging stalactite teeth).
local function addCaveArch(list, prefix, x, z, dirSign)
    -- Left & right sloped ceiling haunches (turning the square tunnel into a natural cavern vault)
    for _, side in { -1, 1 } do
        add(list, {
            kind = "block",
            shape = "Wedge",
            name = prefix .. (side < 0 and "_HaunchN" or "_HaunchS"),
            pos = { x, 13.0, z + side * 10.5 },
            size = { 8, 6, 9 },
            rot = { 0, side < 0 and 180 or 0, 180 },
            color = "StrataSienna",
            material = "Sandstone",
            decor = true,
        })
    end
    -- Jagged rock brow arch & stalactite teeth outside the cave lip
    add(list, {
        kind = "block",
        name = prefix .. "_Brow",
        pos = { x + dirSign * 1.5, 17.5, z },
        size = { 6, 5, 32 },
        color = "StrataRust",
        material = "Sandstone",
        decor = true,
    })
    for i, zOff in { -9, -2, 6 } do
        add(list, {
            kind = "block",
            shape = "Wedge",
            name = prefix .. "_Tooth" .. i,
            pos = { x + dirSign * 2.2, 14.4 - (i % 2) * 0.6, z + zOff },
            size = { 3.2, 3.6 + (i % 2), 3.4 },
            rot = { 180, i * 25, 0 },
            color = "StrataDark",
            material = "Basalt",
            decor = true,
        })
    end
end

-- Natural desert scrub cluster (olive brush + dry crooked branches + scree pebbles).
local function addScrub(list, prefix, x, y, z, s)
    add(list, {
        kind = "block",
        name = prefix .. "_BrushA",
        pos = { x, y + 1.1 * s, z },
        size = { 2.8 * s, 2.2 * s, 2.6 * s },
        rot = { 8, 22, 0 },
        color = "Scrub",
        material = "LeafyGrass",
        decor = true,
    })
    add(list, {
        kind = "block",
        name = prefix .. "_BrushB",
        pos = { x + 1.1 * s, y + 0.75 * s, z - 0.7 * s },
        size = { 1.9 * s, 1.5 * s, 2.0 * s },
        rot = { -10, -35, 0 },
        color = "ScrubDry",
        material = "Grass",
        decor = true,
    })
    add(list, {
        kind = "block",
        name = prefix .. "_Twig",
        pos = { x - 0.4 * s, y + 1.2 * s, z + 0.2 * s },
        size = { 0.45 * s, 2.3 * s, 0.45 * s },
        rot = { 16, 15, 0 },
        color = "DryWood",
        material = "Wood",
        decor = true,
    })
end

-- Distant stratified desert mesa silhouettes across the canyon chasm (no Terrain FillBalls).
local function addDistantMesa(list, prefix, x, z, yBot, h, w, d)
    addStrataStack(list, prefix, x, z, yBot, yBot + h, w, d, 6, true, 8)
    add(list, {
        kind = "block",
        shape = "Wedge",
        name = prefix .. "_TalusW",
        pos = { x - w * 0.58, yBot + h * 0.28, z },
        size = { d * 0.92, h * 0.56, w * 0.36 },
        rot = { 0, -90, 0 },
        color = "StrataRust",
        material = "Sandstone",
        decor = true,
    })
    add(list, {
        kind = "block",
        shape = "Wedge",
        name = prefix .. "_TalusE",
        pos = { x + w * 0.58, yBot + h * 0.28, z },
        size = { d * 0.92, h * 0.56, w * 0.36 },
        rot = { 0, 90, 0 },
        color = "StrataOchre",
        material = "Sandstone",
        decor = true,
    })
end

-- ===== Center Geometry (on X = 0) =====

-- Towering North Mountain Cliff Wall sealing the north edge (top Y = 110).
add(Center, {
    kind = "block",
    name = "NorthCliffWall",
    pos = { 0, 30, -90 },
    size = { 380, 160, 36 },
    color = "StrataSienna",
    material = "Sandstone",
})
addStrataStack(Center, "NorthCliffFace", 0, -72, -55, 112, 370, 8, 12, true, 4.5)
add(Center, {
    kind = "block",
    name = "NorthCliffShelf",
    pos = { 0, 12, -70 },
    size = { 340, 124, 12 },
    color = "StrataRust",
    material = "Sandstone",
})
-- Rugged cliff peaks & wedge buttresses crowning the north wall
for _, px in { -140, -70, 0, 70, 140 } do
    add(Center, {
        kind = "block",
        shape = "Wedge",
        name = "NorthPeakWedge_" .. px,
        pos = { px, 118, -82 },
        size = { 56, 20, 22 },
        rot = { 0, 0, 0 },
        color = "StrataPale",
        material = "Limestone",
        decor = true,
    })
end

-- Cave Tunnel Floor (X: -26..+26, Z: -20..+10, Y_top = 0)
add(Center, {
    kind = "block",
    name = "CaveFloor",
    pos = { 0, -25, -5 },
    size = { 52, 50, 30 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Center, "CaveFloorSkirt", 0, -5, 0, 52, 30, 72)

-- Solid Spur North Neck: seals behind the cave so no ground path wraps north of the ridge.
add(Center, {
    kind = "block",
    name = "SpurNorthBlock",
    pos = { 0, 9, -42 },
    size = { 44, 118, 44 },
    color = "StrataSienna",
    material = "Sandstone",
})
addStrataStack(Center, "SpurNorthStrata", 0, -42, 0, 74, 47, 46, 8, true, 3.0)

-- Solid Spur South Divider: separates cave interior (Z <= 10) from Southern Nose (Z >= 26).
add(Center, {
    kind = "block",
    name = "SpurSouthPillar",
    pos = { 0, 9, 18 },
    size = { 32, 118, 16 },
    color = "StrataRust",
    material = "Sandstone",
})
addStrataStack(Center, "SpurSouthStrata", 0, 18, 0, 72, 35, 19, 8, true, 2.8)

-- Unwalkable Cave Ceiling & Knife-Edge Ridge Spine above the cave (Y = 16..78).
add(Center, {
    kind = "block",
    name = "CaveRoofSpine",
    pos = { 0, 42, -5 },
    size = { 44, 52, 30 },
    color = "StrataOchre",
    material = "Sandstone",
})
add(Center, {
    kind = "block",
    name = "RidgeCrestFin",
    pos = { 0, 72, -16 },
    size = { 16, 16, 68 },
    color = "StrataPale",
    material = "Limestone",
})
-- Sculpted jagged sandstone ridge crest fins & slanted wedges along the spine top (fly-over target)
add(Center, {
    kind = "block",
    shape = "Wedge",
    name = "RidgeCrestProW",
    pos = { 0, 78, 28 },
    size = { 14, 24, 22 },
    rot = { 0, 180, 0 },
    color = "StrataPale",
    material = "Limestone",
    decor = true,
})
add(Center, {
    kind = "block",
    shape = "Wedge",
    name = "RidgeCrestSlopeW",
    pos = { -11, 72, -14 },
    size = { 66, 18, 9 },
    rot = { 0, -90, 0 },
    color = "StrataOchre",
    material = "Sandstone",
    decor = true,
})
add(Center, {
    kind = "block",
    shape = "Wedge",
    name = "RidgeCrestSlopeE",
    pos = { 11, 72, -14 },
    size = { 66, 18, 9 },
    rot = { 0, 90, 0 },
    color = "StrataOchre",
    material = "Sandstone",
    decor = true,
})

-- Vaulted cave arches inside center & warm sunlit ambient bounce
addCaveArch(Center, "CaveArchCenter", 0, -5, 0)
addMonolith(Center, "CaveCenterBoulder", 0, 0, -5, 7, 7, 7, 32, true)
add(Center, {
    kind = "light",
    name = "CaveLightCenter",
    pos = { 0, 13.5, -5 },
    color = "AmberGlow",
    range = 44,
    brightness = 1.35,
})

-- Southern Nose Ledge (Z = +26..+48, Y_top = 0) curving tightly over the chasm.
add(Center, {
    kind = "block",
    name = "NoseFloor",
    pos = { 0, -25, 37 },
    size = { 52, 50, 22 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Center, "NoseCliffSkirt", 0, 37, 0, 52, 22, 75)
add(Center, {
    kind = "block",
    name = "NosePebbleRim",
    pos = { 0, 0.04, 46 },
    size = { 46, 0.12, 4 },
    color = "PebbleTone",
    material = "Pebble",
    decor = true,
})
addMonolith(Center, "NoseTipBoulder", 0, 0, 41, 7, 6.5, 6, 12, true)
addScrub(Center, "NoseScrubTip", -7, 0, 44, 0.9)

-- Distant canyon mesas across the deep chasm (replaces ugly Terrain FillBalls & Water)
addDistantMesa(Center, "FarMesaSouthC", 0, 235, -135, 195, 220, 90)
addDistantMesa(Center, "FarMesaSouthW", -230, 210, -145, 220, 170, 95)
addDistantMesa(Center, "FarMesaSouthE", 230, 210, -145, 220, 170, 95)

-- ===== Mirrored Red-Side (-X) Geometry (Auto-Mirrored to Blue +X) =====

-- Spawn Mesa Plateau (X: -170..-120, Z: -44..+24, top Y = 8)
add(Mirrored, {
    kind = "block",
    name = "SpawnMesa",
    pos = { -145, -21, -10 },
    size = { 50, 58, 68 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "SpawnSkirt", -145, -10, 8, 50, 68, 82)
add(Mirrored, {
    kind = "block",
    name = "SpawnDriftPatch",
    pos = { -152, 8.05, -12 },
    size = { 26, 0.12, 40 },
    color = "SandDrift",
    material = "Ground",
    decor = true,
})

-- Tall sandstone rock fins shielding spawn pads from cross-map sniper lines
addMonolith(Mirrored, "SpawnShieldFinMain", -126, 8, -12, 8, 17, 26, 6, true)
addMonolith(Mirrored, "SpawnShieldFinSouth", -128, 8, 8, 8, 12, 12, -14, true)

-- Minimal natural rock cairn & team cloth pennant
add(Mirrored, {
    kind = "block",
    name = "SpawnCairn",
    pos = { -162, 11, -34 },
    size = { 5, 6, 5 },
    color = "StrataRust",
    material = "Sandstone",
})
add(Mirrored, {
    kind = "block",
    name = "PennantPole",
    pos = { -162, 16, -34 },
    size = { 0.45, 9, 0.45 },
    color = "DryWood",
    material = "Wood",
    decor = true,
})
add(Mirrored, {
    kind = "block",
    name = "TeamPennant",
    pos = { -162, 18.5, -31.5 },
    size = { 0.35, 3.6, 5.2 },
    material = "Fabric",
    decor = true,
})

-- Sunken Anti-Sniper Gulch Lane (Y = 0) + 22-deg sandstone ramp down from Spawn (Y = 8 -> Y = 0)
add(Mirrored, {
    kind = "block",
    name = "GulchRamp",
    pos = { -109, 3.05, -24 },
    size = { 21.5, 2, 16 },
    rot = { 0, 0, -22 },
    color = "SandFloor",
    material = "Sand",
})
add(Mirrored, {
    kind = "block",
    name = "GulchRampBase",
    pos = { -108, -24, -24 },
    size = { 22, 48, 18 },
    color = "StrataSienna",
    material = "Sandstone",
})
addCliffSkirt(Mirrored, "GulchRampSkirt", -108, -24, 0, 22, 18, 72)

add(Mirrored, {
    kind = "block",
    name = "GulchFloor",
    pos = { -63, -25, -5 },
    size = { 74, 50, 46 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "GulchSkirt", -63, -5, 0, 74, 46, 74)
add(Mirrored, {
    kind = "block",
    name = "GulchTrailSand",
    pos = { -66, 0.04, -5 },
    size = { 62, 0.10, 14 },
    color = "SandDrift",
    material = "Ground",
    decor = true,
})

-- Continuous sandstone parapet wall along the southern edge of the gulch (shields from snipers)
add(Mirrored, {
    kind = "block",
    name = "GulchAntiSniperWall",
    pos = { -74, 3.5, 16 },
    size = { 52, 7, 4 },
    color = "StrataRust",
    material = "Sandstone",
})
add(Mirrored, {
    kind = "block",
    name = "GulchParapetCap",
    pos = { -74, 7.2, 16 },
    size = { 53, 1.4, 4.6 },
    color = "StrataPale",
    material = "Limestone",
    decor = true,
})
addMonolith(Mirrored, "GulchCoverA", -88, 0, -4, 8, 6, 7, 18, true)
addMonolith(Mirrored, "GulchCoverB", -54, 0, -10, 8, 6, 8, -22, true)

-- Leaning sandstone monolith outside each cave mouth (blocks straight-down-throat sniper scopes)
addMonolith(Mirrored, "CaveMouthGuardBoulder", -30, 0, -5, 7, 9.5, 8, 15, true)
addCaveArch(Mirrored, "CaveMouthArch", -25, -5, -1)
addMonolith(Mirrored, "CaveFlankPillar", -11, 0, 2, 5, 7, 5, 28, true)
add(Mirrored, {
    kind = "light",
    name = "CaveLightMouth",
    pos = { -20, 12.5, -5 },
    color = "AmberGlow",
    range = 36,
    brightness = 1.15,
})

-- Nose Approach & Rock-to-Rock Cover Beats
add(Mirrored, {
    kind = "block",
    name = "NoseSideLedge",
    pos = { -31, -25, 29 },
    size = { 12, 50, 28 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "NoseSideSkirt", -31, 29, 0, 12, 28, 74)
addMonolith(Mirrored, "NoseCornerBoulder", -19, 0, 34, 6.5, 6, 6.5, -25, true)

-- Upper Flank Trail & Split Sniper Shelves
add(Mirrored, {
    kind = "block",
    name = "UpperFlankStep",
    pos = { -132, 4.5, -46 },
    size = { 28, 9, 22 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "UpperFlankStepSkirt", -132, -46, 9, 28, 22, 82)
add(Mirrored, {
    kind = "block",
    name = "UpperFlankTrail",
    pos = { -104, -20, -48 },
    size = { 30, 60, 22 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "UpperFlankTrailSkirt", -104, -48, 10, 30, 22, 82)
add(Mirrored, {
    kind = "block",
    name = "UpperSniperRamp",
    pos = { -82, 12.1, -52 },
    size = { 16.5, 2, 12 },
    rot = { 0, 0, 22 },
    color = "SandFloor",
    material = "Sand",
})
add(Mirrored, {
    kind = "block",
    name = "UpperSniperShelf",
    pos = { -66, -17, -54 },
    size = { 24, 66, 20 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "UpperSniperSkirt", -66, -54, 16, 24, 20, 88)
addMonolith(Mirrored, "UpperSniperBoulder", -68, 16, -48, 5.5, 3.2, 4.5, 12, true)

-- Protruding rock horn splitting Upper Sniper Shelf from Outer Promontory
addMonolith(Mirrored, "SniperSightlineHorn", -52, 0, -34, 10, 26, 12, -16, true)

-- Forward Outer Sniper Promontory (X = -62, Y = 12, Z = +32), reached via a 20-deg ramp from Spawn.
add(Mirrored, {
    kind = "block",
    name = "OuterPromontoryJoin",
    pos = { -126, -21, 28 },
    size = { 16, 58, 12 },
    color = "SandFloor",
    material = "Sand",
})
add(Mirrored, {
    kind = "block",
    name = "OuterPromontoryPath",
    pos = { -104, -21, 32 },
    size = { 34, 58, 14 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "OuterPathSkirt", -104, 32, 8, 34, 14, 80)
add(Mirrored, {
    kind = "block",
    name = "OuterPromontoryRamp",
    pos = { -81.5, 9.05, 32 },
    size = { 13.5, 2, 12 },
    rot = { 0, 0, 20 },
    color = "SandFloor",
    material = "Sand",
})
add(Mirrored, {
    kind = "block",
    name = "OuterPromontory",
    pos = { -62, -19, 32 },
    size = { 26, 62, 16 },
    color = "SandFloor",
    material = "Sand",
})
addCliffSkirt(Mirrored, "OuterPromSkirt", -62, 32, 12, 26, 16, 84)
addMonolith(Mirrored, "OuterPromontoryBoulder", -56, 12, 27, 5, 3.2, 5, 18, true)

-- Natural desert scrub & distant canyon flank mesa silhouettes
addScrub(Mirrored, "ScrubSpawn", -136, 8, 16, 1.1)
addScrub(Mirrored, "ScrubGulch", -42, 0, -21, 1.0)
addScrub(Mirrored, "ScrubUpper", -74, 16, -61, 0.95)
addDistantMesa(Mirrored, "FarMesaFlank", -295, 25, -140, 210, 95, 190)

return {
    Name = "ChokeRidge",
    DisplayName = "Choke Ridge",
    Size = 420,
    WallHeight = 140,
    Seed = 404,

    Spawns = {
        Red = {
            { -154, 8.5, -26 },
            { -154, 8.5, -14 },
            { -154, 8.5, -2 },
            { -142, 8.5, -26 },
            { -142, 8.5, -14 },
            { -142, 8.5, -2 },
        },
        Blue = {
            { 154, 8.5, -26 },
            { 154, 8.5, -14 },
            { 154, 8.5, -2 },
            { 142, 8.5, -26 },
            { 142, 8.5, -14 },
            { 142, 8.5, -2 },
        },
    },

    Objectives = {
        { Id = "A", Name = "North Cavern", pos = { 0, 0, -10 }, radius = 12, halfHeight = 10, Phases = { 1 } },
        { Id = "B", Name = "South Cavern", pos = { 0, 0, 2 }, radius = 12, halfHeight = 10, Phases = { 1, 2 } },
        { Id = "C", Name = "The Nose", pos = { 0, 0, 38 }, radius = 12, halfHeight = 12, Phases = { 1, 2, 3 } },
    },

    Vista = { pos = { -160, 72, 130 }, look = { 0, 12, -10 }, seconds = 2.5 },

    RecoveryY = -30,
    Bounds = { min = { -185, -32, -110 }, max = { 185, 290, 80 } },
    InvalidRegions = {},
    SafeRegions = {},
    SafePoints = {
        { name = "Red Spawn Mesa", pos = { -146, 9.5, -14 } },
        { name = "Blue Spawn Mesa", pos = { 146, 9.5, -14 } },
        { name = "West Gulch", pos = { -68, 1, -10 } },
        { name = "East Gulch", pos = { 68, 1, -10 } },
        { name = "Cave Heart", pos = { 0, 1, -4 } },
        { name = "Southern Nose", pos = { 0, 1, 38 } },
    },

    Barrier = {
        { pos = { 0, 6, 49.5 }, size = { 52, 12, 1.5 } },
        { pos = { -27.5, 6, 30 }, size = { 1.5, 12, 38 } },
        { pos = { 27.5, 6, 30 }, size = { 1.5, 12, 38 } },
        { pos = { -38, 6, 19.5 }, size = { 22, 12, 1.5 } },
        { pos = { 38, 6, 19.5 }, size = { 22, 12, 1.5 } },
        { pos = { -84, 16, 41.5 }, size = { 72, 12, 1.5 } },
        { pos = { 84, 16, 41.5 }, size = { 72, 12, 1.5 } },
        { pos = { -145, 14, 25.5 }, size = { 50, 12, 1.5 } },
        { pos = { 145, 14, 25.5 }, size = { 50, 12, 1.5 } },
        { pos = { -171.5, 14, -10 }, size = { 1.5, 12, 70 } },
        { pos = { 171.5, 14, -10 }, size = { 1.5, 12, 70 } },
    },

    SniperOutposts = {
        { Name = "West Upper Shelf", pos = { -66, 16, -54 }, radius = 10 },
        { Name = "East Upper Shelf", pos = { 66, 16, -54 }, radius = 10 },
        { Name = "West Outer Promontory", pos = { -62, 12, 32 }, radius = 9 },
        { Name = "East Outer Promontory", pos = { 62, 12, 32 }, radius = 9 },
    },

    Pickups = {
        { kind = "jetpack", pos = { -84, 1.2, -16 }, respawn = 45, fuel = 3.5 },
        { kind = "jetpack", pos = { 84, 1.2, -16 }, respawn = 45, fuel = 3.5 },
        { kind = "weapon", weapon = "Shotgun", pos = { 0, 1.2, 4 }, respawn = 55, duration = 40 },
        {
            kind = "weapon",
            weapon = "WhiteSniper",
            pos = { -62, 13.0, 32 },
            respawnTuning = "WhiteSniperRespawnSeconds",
            respawnOnDeath = true,
        },
        {
            kind = "weapon",
            weapon = "WhiteSniper",
            pos = { 62, 13.0, 32 },
            respawnTuning = "WhiteSniperRespawnSeconds",
            respawnOnDeath = true,
        },
        { kind = "speed", pos = { -96, 11.2, -46 } },
        { kind = "speed", pos = { 96, 11.2, -46 } },
    },

    -- Golden-hour desert canyon lighting & atmospheric chasm haze (no water, no Terrain balls).
    Environment = {
        ClockTime = 16.6,
        Brightness = 2.6,
        Ambient = Color3.fromRGB(134, 106, 86),
        OutdoorAmbient = Color3.fromRGB(172, 138, 108),
        FogColor = Color3.fromRGB(228, 186, 142),
        FogStart = 220,
        FogEnd = 1200,
        Atmosphere = {
            Density = 0.28,
            Haze = 1.6,
            Glare = 0.28,
            Color = Color3.fromRGB(238, 196, 150),
            Decay = Color3.fromRGB(152, 104, 72),
        },
        SunRays = 0.16,
        Bloom = 0.10,
        Saturation = 0.20,
        Contrast = 0.12,
        Tint = Color3.fromRGB(255, 245, 232),
    },

    Palette = {
        SandFloor = Color3.fromRGB(226, 178, 126),
        SandDrift = Color3.fromRGB(212, 158, 108),
        PebbleTone = Color3.fromRGB(196, 146, 102),
        StrataPale = Color3.fromRGB(230, 186, 138),
        StrataOchre = Color3.fromRGB(204, 134, 84),
        StrataRust = Color3.fromRGB(178, 96, 56),
        StrataSienna = Color3.fromRGB(140, 74, 46),
        StrataDark = Color3.fromRGB(102, 54, 36),
        Boulder = Color3.fromRGB(186, 114, 72),
        Rock = Color3.fromRGB(186, 114, 72),
        RockMaterial = Enum.Material.Slate,
        MaterialVariants = {
            SandFloor = "Desert_SandFloor",
            SandDrift = "Desert_SandFloor",
            StrataPale = "Desert_Sandstone",
            StrataOchre = "Desert_Sandstone",
            StrataRust = "Desert_Sandstone",
            StrataSienna = "Desert_SandstoneDark",
            StrataDark = "Desert_SandstoneDark",
            Boulder = "Desert_Boulder",
            Rock = "Desert_Boulder",
        },
        Scrub = Color3.fromRGB(98, 114, 62),
        ScrubDry = Color3.fromRGB(142, 128, 76),
        DryWood = Color3.fromRGB(122, 88, 56),
        AmberGlow = Color3.fromRGB(255, 196, 132),
    },

    -- Void clears workspace.Terrain completely: zero water underneath, zero Terrain balls.
    Terrain = {
        Void = true,
    },

    Center = Center,
    Mirrored = Mirrored,
}
