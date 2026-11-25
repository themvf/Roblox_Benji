-- Penthouse: the design, as data. tools/map_generate.luau turns this into Penthouse.rbxm.
--
-- This file is the thing to edit. The .rbxm is rebuilt from it, so changes made to the
-- .rbxm in Studio are lost on the next generate (move them back into here, or stop
-- generating and treat the .rbxm as hand-authored from then on).
--
-- Coordinates: x runs between the teams (Blue west at -x, Red east at +x), z runs across
-- the three lanes (north terrace at -z, south gallery at +z), y is up, floor top at y = 0.
-- Only the west half is written. Anything without `mirror = false` is copied to the east
-- half at -x, so both teams get the same distances; a look's `east` table changes how the
-- copy is dressed, never its shape.
--
-- Every wall and block is 2 studs or thicker and sits on even coordinates: the measuring
-- tool samples the map on a 2-stud grid and must not step over a wall.
--
-- Door rule: every doorway has a full-height screen wider than itself about 10 studs
-- behind it. Doors on a regular grid line up diagonally (the first draft had a 215-stud
-- line of fire through five of them); a screened door is an L-bend, not a window.
--
-- Rows (z):    terrace -90..-34 | glass front -32 | middle -30..24 | wall 26 | south 28..88
-- Columns (x): team end -138..-104 | wall -102 | front rooms -100..-52 | wall -50 | core -48..48
local FLOOR, ROOF = 0, 30
local MEZZ = 14

local looks = {
    Floor = { color = { 214, 210, 202 }, material = "Marble" },
    Deck = { color = { 118, 96, 78 }, material = "WoodPlanks" },
    Wall = { color = { 232, 228, 220 }, material = "SmoothPlastic" },
    -- Rails only. Walls are solid with Window panes: whole walls of tinted glass were hard
    -- to see through and did not read as a building.
    Glass = { color = { 210, 228, 236 }, material = "Glass", transparency = 0.8 },
    Window = { color = { 222, 236, 242 }, material = "Glass", transparency = 0.88 },
    Roof = { color = { 54, 56, 62 }, material = "Concrete" },
    Column = { color = { 44, 46, 52 }, material = "Metal" },
    Mezz = { color = { 96, 74, 58 }, material = "WoodPlanks" },
    -- Full cover blocks a standing player; the neon band on top is the side's colour.
    Cover = { color = { 62, 66, 76 }, material = "Concrete", band = true },
    -- Low cover (3.5 studs): crouch behind it, shoot over it.
    Furniture = { color = { 152, 124, 96 }, material = "Wood", east = { color = { 96, 104, 120 } } },
    Planter = { color = { 78, 82, 78 }, material = "Concrete", band = true },
    Accent = { color = { 70, 160, 255 }, material = "Neon", east = { color = { 255, 150, 60 } } },
    Rug = { color = { 46, 78, 128 }, material = "Fabric", east = { color = { 140, 72, 44 } } },
    Water = { color = { 60, 170, 210 }, material = "Glass", transparency = 0.35 },
    Tower = { color = { 26, 30, 38 }, material = "Concrete" },
    Windows = { color = { 255, 214, 150 }, material = "Neon" },
    Lamp = { color = { 255, 236, 204 }, material = "Neon" },
}

local parts = {
    -- ===== shell (centre pieces, written once) =====
    { kind = "box", group = "Ground", name = "Floor", min = { -140, -2, -90 }, max = { 140, FLOOR, 90 }, look = "Floor", mirror = false, structure = true },
    { kind = "box", name = "Roof", min = { -140, ROOF, -33 }, max = { 140, ROOF + 2, 90 }, look = "Roof", mirror = false, structure = true },

    -- Front wall between the terrace and the rooms: solid, with wide windows and three doors per side.
    {
        kind = "wall", name = "GlassFront", axis = "z", at = -32, from = -140, to = 0, y0 = FLOOR, y1 = ROOF, look = "Wall",
        windows = { sill = 2, head = 14, bay = 16, pier = 4 },
        doors = { { at = -110, width = 10, top = 9 }, { at = -66, width = 10, top = 9 }, { at = -3, width = 6, top = 10 } },
    },
    -- Wall between the middle rooms and the south rooms. The high opening is where the
    -- gallery stair reaches the mezzanine.
    {
        kind = "wall", name = "SouthPartition", axis = "z", at = 26, from = -140, to = 0, y0 = FLOOR, y1 = ROOF, look = "Wall",
        doors = {
            { at = -110, width = 10, top = 9 },
            { at = -88, width = 10, top = 9 },
            { at = -44, width = 8, bottom = MEZZ, top = MEZZ + 10 },
            { at = -3, width = 6, top = 10 },
        },
    },
    -- Team end | front rooms. The middle door is the spawn's main exit.
    {
        kind = "wall", name = "EndWall", axis = "x", at = -102, from = -31, to = 89, y0 = FLOOR, y1 = ROOF, look = "Wall",
        doors = { { at = -3, width = 12, top = 10 }, { at = 58, width = 10, top = 9 } },
    },
    -- Front rooms | core. The atrium door passes under the mezzanine.
    {
        kind = "wall", name = "CoreWall", axis = "x", at = -50, from = -31, to = 89, y0 = FLOOR, y1 = ROOF, look = "Wall",
        doors = { { at = -3, width = 16, top = 12 }, { at = 72, width = 12, top = 10 } },
    },
    -- Outer envelope: windowed walls round the rooms, a glass rail round the terrace.
    { kind = "wall", name = "WestGlass", axis = "x", at = -139, from = -33, to = 90, y0 = FLOOR, y1 = ROOF, look = "Wall", windows = { sill = 3, head = 14, bay = 20, pier = 4 } },
    { kind = "wall", name = "SouthGlass", axis = "z", at = 89, from = -140, to = 0, y0 = FLOOR, y1 = ROOF, look = "Wall", windows = { sill = 3, head = 14, bay = 20, pier = 4 } },
    { kind = "wall", name = "TerraceRailNorth", axis = "z", at = -89, from = -140, to = 0, y0 = FLOOR, y1 = 6, look = "Glass" },
    { kind = "wall", name = "TerraceRailWest", axis = "x", at = -139, from = -90, to = -33, y0 = FLOOR, y1 = 6, look = "Glass" },

    -- ===== mezzanine: the vantage point over the atrium, two ways up =====
    { kind = "box", name = "Mezzanine", min = { -49, MEZZ - 1, -31 }, max = { -36, MEZZ, 25 }, look = "Mezz", structure = true },
    { kind = "box", name = "MezzLandingA", min = { -36, MEZZ - 1, -18 }, max = { -28, MEZZ, -10 }, look = "Mezz", structure = true },
    { kind = "box", name = "MezzLandingB", min = { -48, MEZZ - 1, 25 }, max = { -40, MEZZ, 30 }, look = "Mezz", structure = true },
    { kind = "box", name = "MezzRailNorth", min = { -38, MEZZ, -30 }, max = { -36, MEZZ + 2.5, -18 }, look = "Glass", structure = true },
    { kind = "box", name = "MezzRailSouth", min = { -38, MEZZ, -10 }, max = { -36, MEZZ + 2.5, 24 }, look = "Glass", structure = true },
    { kind = "box", name = "LandingRailEast", min = { -30, MEZZ, -18 }, max = { -28, MEZZ + 2.5, -10 }, look = "Glass", structure = true },
    { kind = "box", name = "LandingRailNorth", min = { -36, MEZZ, -18 }, max = { -30, MEZZ + 2.5, -16 }, look = "Glass", structure = true },
    -- Atrium stair: with the pier under its landing it is one solid mass from z = -18 to 18,
    -- which is what stops every view from the west door through the north or south door.
    { kind = "box", name = "LandingPier", min = { -36, FLOOR, -18 }, max = { -28, MEZZ - 1, -10 }, look = "Column", becomes = "marble-clad pier carrying the stair landing", finish = true },
    { kind = "ramp", name = "AtriumStair", low = { -32, FLOOR, 18 }, high = { -32, MEZZ, -10 }, width = 8, look = "Mezz" },
    -- Gallery stair, up through the south partition.
    { kind = "ramp", name = "GalleryStair", low = { -44, FLOOR, 58 }, high = { -44, MEZZ, 30 }, width = 8, look = "Mezz" },

    -- ===== team end: spawn hall, with something solid in front of every exit =====
    { kind = "box", name = "ElevatorCore", min = { -120, FLOOR, -14 }, max = { -118, 11, 8 }, look = "Column", shell = { asset = "elevator", pieces = 2, flip = true } },
    -- A vestibule outside each side door, open only to the west. A pad can then be seen
    -- through a side door only from inside the vestibule, not from 135 studs down the terrace,
    -- and the two side doors no longer make one 160-stud corridor through the spawn hall.
    { kind = "cover", name = "VestibuleNorthCap", min = { -126, -46 }, max = { -98, -42 }, h = 8, look = "Planter", shell = { asset = "hedge", pieces = 4 } },
    { kind = "cover", name = "VestibuleNorthSide", min = { -102, -42 }, max = { -98, -33 }, h = 8, look = "Planter", shell = { asset = "hedge" } },
    { kind = "cover", name = "VestibuleSouthCap", min = { -126, 38 }, max = { -103, 42 }, h = 9, look = "Cover", shell = { asset = "shelving", pieces = 3 } },
    { kind = "cover", name = "ServiceCrates", min = { -116, 50 }, max = { -112, 66 }, h = 9, look = "Cover", shell = { asset = "shelving", pieces = 2 } },

    -- ===== north lane: open terrace, long views broken by staggered blocks =====
    { kind = "cover", name = "CabanaWall", min = { -86, -80 }, max = { -82, -52 }, h = 9, look = "Cover", shell = { asset = "firewall", pieces = 2 } },
    { kind = "cover", name = "PlanterOuter", min = { -48, -88 }, max = { -44, -66 }, h = 8, look = "Planter", shell = { asset = "hedge", pieces = 3 } },
    { kind = "cover", name = "PlanterInner", min = { -36, -56 }, max = { -32, -34 }, h = 8, look = "Planter", shell = { asset = "hedge", pieces = 3 } },
    { kind = "cover", name = "PoolBarWall", min = { -24, -70 }, max = { -20, -54 }, h = 7, look = "Cover", shell = { asset = "poolbar" } },
    { kind = "cover", name = "TerraceScreen", min = { -12, -46 }, max = { 12, -42 }, h = 8, look = "Planter", mirror = false, shell = { asset = "hedge", pieces = 3 } },
    { kind = "cover", name = "TerraceDoorPlanter", min = { -78, -46 }, max = { -54, -42 }, h = 8, look = "Planter", shell = { asset = "hedge", pieces = 3 } },
    -- a daybed is a 2-stud platform with a soft backrest: something to hop over, not cover
    { kind = "cover", name = "LoungerB", min = { -104, -80 }, max = { -96, -76 }, h = 2, look = "Furniture", shell = { asset = "daybed" } },

    -- ===== middle lane: foyer, then the double-height atrium =====
    -- Stands between the spawn door and the atrium door. Without it the spawn hall could
    -- see the enemy mezzanine 164 studs away, and the foyer could see into the far gallery.
    { kind = "cover", name = "FoyerScreen", min = { -66, -16 }, max = { -64, 10 }, h = 10, look = "Cover", shell = { asset = "aquarium", pieces = 2 } },
    { kind = "cover", name = "ReceptionWall", min = { -92, -14 }, max = { -88, 8 }, h = 10, look = "Cover", shell = { asset = "slatscreen", pieces = 2 } },
    { kind = "cover", name = "ReceptionDesk", min = { -80, -8 }, max = { -76, 4 }, h = 3.5, look = "Furniture", shell = { asset = "island" } },
    { kind = "cover", name = "AtriumSofa", min = { -18, -12 }, max = { -14, 4 }, h = 3.5, look = "Furniture", shell = { asset = "sofa" } },

    -- ===== south lane: kitchen, then the gallery. Close quarters =====
    { kind = "cover", name = "Pantry", min = { -96, 36 }, max = { -80, 40 }, h = 10, look = "Cover", shell = { asset = "cabinetwall", pieces = 2 } },
    { kind = "cover", name = "KitchenIslandS", min = { -88, 68 }, max = { -76, 72 }, h = 3.5, look = "Furniture", shell = { asset = "island" } },
    { kind = "cover", name = "FridgeBank", min = { -64, 60 }, max = { -60, 84 }, h = 10, look = "Cover", shell = { asset = "cabinetwall", pieces = 3 } },
    { kind = "cover", name = "PlinthN", min = { -26, 42 }, max = { -22, 46 }, h = 7, look = "Cover", shell = { asset = "statue" } },
    { kind = "cover", name = "PlinthS", min = { -26, 74 }, max = { -22, 78 }, h = 7, look = "Cover", shell = { asset = "statue" } },
    { kind = "cover", name = "GalleryBench", min = { -22, 82 }, max = { -14, 86 }, h = 2, look = "Furniture", shell = { asset = "daybed" } },
    { kind = "cover", name = "GalleryScreen", min = { -12, 36 }, max = { 12, 38 }, h = 9, look = "Cover", mirror = false, shell = { asset = "gallerywall", pieces = 2 } },
    -- Stops the 200-stud view from one kitchen through both gallery doors to the other.
    { kind = "cover", name = "Sculpture", min = { -6, 64 }, max = { 6, 80 }, h = 16, look = "Column", mirror = false, shell = { asset = "sculpture" } },

    -- ===== dressing: seen, never touched (collide = false) =====
    { kind = "box", name = "Pool", min = { -18, FLOOR, -86 }, max = { 18, FLOOR + 0.2, -74 }, look = "Water", collide = false, mirror = false },
    { kind = "box", name = "TerraceDeck", min = { -138, FLOOR, -88 }, max = { 0, FLOOR + 0.1, -34 }, look = "Deck", collide = false },
    { kind = "box", name = "FoyerRug", min = { -98, FLOOR, -26 }, max = { -54, FLOOR + 0.1, 20 }, look = "Rug", collide = false },
    { kind = "box", name = "AtriumRug", min = { -30, FLOOR, -22 }, max = { 0, FLOOR + 0.1, 14 }, look = "Rug", collide = false },
    { kind = "box", name = "FoyerFeatureWall", min = { -101, 4, -28 }, max = { -100.6, 22, -12 }, look = "Accent", collide = false },
    { kind = "box", name = "KitchenFeatureWall", min = { -101, 4, 34 }, max = { -100.6, 22, 48 }, look = "Accent", collide = false },
    { kind = "box", name = "MezzEdgeLight", min = { -36.2, MEZZ - 1, -30 }, max = { -36, MEZZ - 0.6, 24 }, look = "Accent", collide = false },
    { kind = "box", name = "Chandelier", min = { -5, 20, -8 }, max = { 5, 24, 2 }, look = "Lamp", collide = false, mirror = false },
    { kind = "box", name = "TowerShaft", min = { -134, -420, -84 }, max = { 134, -2, 84 }, look = "Tower", collide = false, mirror = false },
    -- Landmarks outside the glass, different on each side, so "spire side" and "helipad
    -- side" are callouts from the terrace and through the windows.
    { kind = "box", name = "SpireTower", min = { -250, -420, -40 }, max = { -200, 60, 10 }, look = "Tower", collide = false, mirror = false },
    { kind = "box", name = "HelipadTower", min = { 200, -420, -50 }, max = { 270, -12, 20 }, look = "Tower", collide = false, mirror = false },
    { kind = "box", name = "HelipadDeck", min = { 196, -12, -54 }, max = { 274, -10, 24 }, look = "Roof", collide = false, mirror = false },
    { kind = "box", name = "HelipadRing", min = { 216, -10, -34 }, max = { 254, -9.8, 4 }, look = "Windows", collide = false, mirror = false },
    { kind = "box", name = "SkylineA", min = { -120, -420, -330 }, max = { -40, 40, -250 }, look = "Tower", collide = false, mirror = false },
    { kind = "box", name = "SkylineB", min = { 60, -420, -300 }, max = { 130, -40, -230 }, look = "Tower", collide = false, mirror = false },
    { kind = "box", name = "SkylineC", min = { -60, -420, 240 }, max = { 30, 10, 320 }, look = "Tower", collide = false, mirror = false },
    { kind = "box", name = "SkylineAWindows", min = { -121, -60, -249.5 }, max = { -39, 30, -249 }, look = "Windows", collide = false, mirror = false },
    { kind = "box", name = "SkylineCWindows", min = { -61, -90, 239 }, max = { 31, 0, 239.5 }, look = "Windows", collide = false, mirror = false },

    -- ===== lights: the rooms are under a roof and get no sun =====
    { kind = "light", name = "SpawnLight", at = { -124, 27, -3 }, range = 44, brightness = 1.6 },
    { kind = "light", name = "FoyerLight", at = { -78, 27, -3 }, range = 48, brightness = 1.6 },
    { kind = "light", name = "AtriumLightN", at = { -18, 27, -18 }, range = 46, brightness = 1.4 },
    { kind = "light", name = "AtriumLightS", at = { -18, 27, 12 }, range = 46, brightness = 1.4 },
    { kind = "light", name = "UnderMezzLight", at = { -42, 11.5, -3 }, range = 26, brightness = 1.2 },
    { kind = "light", name = "ServiceLight", at = { -122, 27, 58 }, range = 48, brightness = 1.4 },
    { kind = "light", name = "KitchenLight", at = { -76, 27, 58 }, range = 50, brightness = 1.7 },
    { kind = "light", name = "GalleryLight", at = { -24, 27, 58 }, range = 50, brightness = 1.3 },
    { kind = "light", name = "TerraceLampA", at = { -100, 8, -62 }, range = 34, brightness = 1.0 },
    { kind = "light", name = "TerraceLampB", at = { -40, 8, -62 }, range = 34, brightness = 1.0 },
}

return {
    name = "Penthouse",
    looks = looks,
    parts = parts,
    -- Uploaded models the map draws. `registry` names an entry in src/shared/AssetRegistry.json
    -- (anything built by tools/asset_generate.py); `id` is a raw Roblox model id for models
    -- that are not in the registry. `glb` is the file on disk, which the preview renderer
    -- uses. A registry entry that is not uploaded yet is skipped in game and its block stays.
    assets = {
        palm = { id = 84316532447768, glb = "assets/models/palm-tree-1/exports/PalmTree1.glb", is = "palm tree" },
        blackhawk = { id = 106361454815274, glb = "assets/models/black-hawk/exports/BlackHawk.glb", is = "parked helicopter" },
        radiotower = { registry = "radio-tower", glb = "assets/models/radio-tower/exports/RadioTower.glb", is = "radio tower" },
        sofa = { registry = "penthouse-sofa", glb = "assets/models/penthouse-sofa/exports/PenthouseSofa.glb", is = "sectional sofa" },
        daybed = { registry = "penthouse-daybed", glb = "assets/models/penthouse-daybed/exports/PenthouseDaybed.glb", long = "z", is = "daybed" },
        island = { registry = "penthouse-kitchen-island", glb = "assets/models/penthouse-kitchen-island/exports/PenthouseKitchenIsland.glb", is = "kitchen island counter" },
        sculpture = { registry = "penthouse-sculpture", glb = "assets/models/penthouse-sculpture/exports/PenthouseSculpture.glb", long = "z", is = "bronze sculpture" },
        -- Not made yet. `is` is what the block becomes; `want` is the brief for
        -- asset-from-prompt. The size each piece must fill is worked out from the blocks
        -- that use it and listed in docs/design/penthouse/blocks.md.
        hedge = { registry = "penthouse-hedge", glb = "assets/models/penthouse-hedge/exports/PenthouseHedgeClean.glb", is = "clipped hedge in a stone planter", want = "A straight section of dense clipped boxwood hedge growing out of a long rectangular honed-limestone planter box, flat top, square ends so sections butt together" },
        elevator = { registry = "penthouse-elevator", glb = "assets/models/penthouse-elevator/exports/PenthouseElevator.glb", is = "elevator doors in a marble surround", want = "A freestanding section of wall with one pair of closed brushed-steel elevator doors set in a white marble surround, call button panel beside the doors, plain marble on the back" },
        shelving = { registry = "penthouse-shelving", glb = "assets/models/penthouse-shelving/exports/PenthouseShelving.glb", is = "storage shelving stacked with boxes", want = "A tall steel storage shelving unit, fully stocked with closed cardboard boxes and linen bins so nothing can be seen through it, solid back panel" },
        firewall = { registry = "penthouse-fire-wall", glb = "assets/models/penthouse-fire-wall/exports/PenthouseFireWall.glb", is = "outdoor fireplace wall", want = "A freestanding outdoor feature wall in dark stacked slate with a long linear gas fireplace slot at seat height, flat concrete cap, same on both faces" },
        poolbar = { registry = "penthouse-pool-bar", glb = "assets/models/penthouse-pool-bar/exports/PenthousePoolBar.glb", is = "pool bar", want = "A freestanding outdoor bar: a teak-fronted counter with a stone top and a tall back shelf wall stocked with bottles behind it, built as one solid block" },
        aquarium = { registry = "penthouse-aquarium", glb = "assets/models/penthouse-aquarium/exports/PenthouseAquarium.glb", is = "built-in aquarium wall", want = "A freestanding room-divider wall with a large aquarium tank set into it, blue lit water with coral and fish visible on both faces, dark walnut frame above and below" },
        slatscreen = { registry = "penthouse-slat-screen", glb = "assets/models/penthouse-slat-screen/exports/PenthouseSlatScreen.glb", is = "walnut slat screen with artwork", want = "A freestanding interior feature wall of closely spaced vertical walnut slats on a solid dark backing, with one large abstract canvas hung in the centre of each face" },
        cabinetwall = { registry = "penthouse-cabinet-wall", glb = "assets/models/penthouse-cabinet-wall/exports/PenthouseCabinetWall.glb", is = "kitchen cabinet wall with ovens and fridge", want = "A tall run of handleless matte charcoal kitchen cabinets with a built-in double oven and an integrated steel fridge door, plain panelled back" },
        statue = { registry = "penthouse-statue", glb = "assets/models/penthouse-statue/exports/PenthouseStatue.glb", is = "marble bust on a plinth", want = "A classical white marble bust on a tall square black stone plinth" },
        gallerywall = { registry = "penthouse-gallery-wall", glb = "assets/models/penthouse-gallery-wall/exports/PenthouseGalleryWall.glb", is = "freestanding gallery wall with paintings", want = "A freestanding white gallery display wall on a low black base, three framed modern paintings hung in a row on each face" },
    },
    -- Props are drawn with no collision. `at` is the point the prop stands on, `fit` the
    -- length in studs of its longer side on the ground, `box` the size of its marker in
    -- Studio. Mirrored like everything else unless `mirror = false`.
    props = {
        -- the two outside landmarks: "spire side" (west) and "helipad side" (east)
        { name = "RadioSpire", asset = "radiotower", at = { -225, 60, -15 }, fit = 26, box = { 20, 92, 26 }, mirror = false },
        { name = "ParkedBlackHawk", asset = "blackhawk", at = { 235, -10, -15 }, fit = 46, box = { 46, 14, 40 }, mirror = false },
        -- palms standing in the terrace planters (the planter top is the y)
        { name = "PalmOuterPlanter", asset = "palm", at = { -46, 8, -78 }, fit = 6, box = { 6, 12, 6 } },
        { name = "PalmInnerPlanter", asset = "palm", at = { -34, 8, -45 }, fit = 6, box = { 6, 12, 6 } },
        { name = "PalmDoorPlanterA", asset = "palm", at = { -72, 8, -44 }, fit = 6, box = { 6, 12, 6 } },
        { name = "PalmDoorPlanterB", asset = "palm", at = { -60, 8, -44 }, fit = 6, box = { 6, 12, 6 } },
        { name = "PalmVestibule", asset = "palm", at = { -112, 8, -44 }, fit = 6, box = { 6, 12, 6 } },
        { name = "PalmTerraceScreen", asset = "palm", at = { -8, 8, -44 }, fit = 6, box = { 6, 12, 6 } },
        -- indoor palms in corners, clear of every route
        { name = "PalmFoyer", asset = "palm", at = { -98, 0, -28 }, fit = 5, box = { 5, 10, 5 } },
        { name = "PalmUnderMezzanine", asset = "palm", at = { -47, 0, 22 }, fit = 5, box = { 5, 10, 5 } },
    },
    objectives = {
        { id = "A", label = "Pool Deck", pos = { 0, FLOOR, -62 }, radius = 12, halfHeight = 7 },
        { id = "B", label = "Gallery", pos = { 0, FLOOR, 50 }, radius = 12, halfHeight = 7 },
        { id = "C", label = "Atrium", pos = { 0, FLOOR, -3 }, radius = 12, halfHeight = 7 },
    },
    -- Blue pads; Red gets the mirror image.
    spawns = { { -130, FLOOR, -22 }, { -130, FLOOR, -14 }, { -130, FLOOR, -6 }, { -130, FLOOR, 2 }, { -130, FLOOR, 10 }, { -130, FLOOR, 18 } },
    bounds = { min = { -144, -12, -94 }, max = { 144, 85, 94 } },

    -- What tools/measure_map.luau checks, and the numbers it checks against. The targets
    -- are first guesses: tune them against a map that is known to play well.
    measure = {
        lanes = {
            { name = "North (terrace)", via = { { -126, FLOOR, -40 }, { -70, FLOOR, -66 } }, objective = "A" },
            { name = "Middle (atrium)", via = { { -96, FLOOR, -3 }, { -58, FLOOR, -3 } }, objective = "C" },
            { name = "South (gallery)", via = { { -126, FLOOR, 34 }, { -96, FLOOR, 58 }, { -58, FLOOR, 72 } }, objective = "B" },
        },
        -- Deliberate narrowings. Each must have a way round it.
        chokes = {
            { name = "Spawn main door", min = { -104, -10 }, max = { -100, 4 } },
            { name = "Spawn north door", min = { -116, -34 }, max = { -104, -30 } },
            { name = "Spawn south door", min = { -116, 24 }, max = { -104, 28 } },
            { name = "Atrium west door", min = { -52, -12 }, max = { -48, 6 } },
            { name = "Atrium north door", min = { -8, -34 }, max = { 8, -30 } },
            { name = "Atrium south door", min = { -8, 24 }, max = { 8, 28 } },
            { name = "Gallery west door", min = { -52, 64 }, max = { -48, 80 } },
            { name = "Kitchen door", min = { -104, 52 }, max = { -100, 64 } },
            { name = "Foyer terrace door", min = { -72, -34 }, max = { -60, -30 } },
            { name = "Foyer kitchen door", min = { -94, 24 }, max = { -82, 28 } },
        },
        vantages = {
            {
                name = "West mezzanine",
                at = { -40, MEZZ, -3 },
                approaches = {
                    { name = "Atrium stair", min = { -36, -10 }, max = { -28, 18 } },
                    { name = "Gallery stair", min = { -48, 30 }, max = { -40, 58 } },
                },
            },
        },
        targets = {
            maxSightline = 120, -- studs, anywhere a player can stand
            minLaneWidth = 8, -- studs, narrowest point on a lane
            maxChokeDetour = 2.5, -- going round a blocked choke may cost at most this many times the direct route
            flankRatio = { 1.1, 2.2 }, -- the next-best lane to an objective, relative to the best
            firstObjective = { 6, 16 }, -- seconds from spawn to the nearest objective
            balance = 0.5, -- seconds a team may be ahead to any objective
            spawnExposure = 70, -- studs: the furthest a spawn pad may be shot from
        },
        -- Player's-eye renders: from, looking at.
        views = {
            { name = "terrace-hedges", eye = { -64, 4.5, -64 }, look = { -40, 5, -50 } },
            { name = "spawn-elevators", eye = { -132, 4.5, 14 }, look = { -119, 5, -3 } },
            { name = "foyer-aquarium", eye = { -80, 4.5, 14 }, look = { -65, 5, -3 } },
            { name = "gallery-wall", eye = { -24, 4.5, 60 }, look = { 0, 4, 38 } },
            { name = "atrium", eye = { -22, 4.5, 16 }, look = { 6, 7, -30 } },
            { name = "terrace-door", eye = { -66, 4.5, -36 }, look = { -66, 5, -60 } },
        },
    },
}
