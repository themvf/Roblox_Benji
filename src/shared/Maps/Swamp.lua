-- Swamp: a Convergence battlefield built around one contested water basin.
--
-- X is west-east, Z is north-south (-Z is north). Blue spawns west (-X), Red east (+X),
-- as the concept sketch draws it and as the Snow Fortress redesign now does -- its gate,
-- tools/check_fortress_layout.luau, asserts "Blue west, Red east exterior starts".
-- MapService names `Mirrored` parts Red_<name> at the authored coordinates and Blue_<name>
-- at the x-mirror, but nothing reads that prefix: it is a Part name, not a team assignment,
-- so it does not constrain which side either team starts on.
--
-- Three districts, all on the centre line so neither team gets a short run:
--   Trestle Bridge (elevated, north)  ->  The Basin (wet, centre)  ->  Cypress Delta (south)
-- The swamp itself is the movement tax that makes a rotation cost something.
--
-- Sources of truth this file is written against:
--   * src/shared/Maps/Validate.lua  - geometry, mirror symmetry and safety rules
--   * src/server/FinalePlan.lua     - exactly three objectives with unique string Ids
--   * src/server/Services/MapService.lua - piece kinds, palette magic keys, terrain carve
-- See docs/design/swamp/ for the concept sketch and the design packet.
local map = {
    Name = "Swamp",
    Revision = "swamp-basin-v1",
    Size = 420, -- a NUMBER: boundary walls at +-210, 2 thick, inner faces +-209
    WallHeight = 48,
    Seed = 2207, -- load-bearing: rocks then Trees draw one shared Random in order
    SafetyAlwaysOn = true, -- SafetyService:BuildBarrier gates on this

    -- No Symmetry override: every list below pairs on the pure x-mirror.
    -- No Prefabs/kind="prefab" (Validate.KINDS has no entry, so check_maps hard-errors).
    -- No MirroredZ (Validate.solids never walks it, so those pieces are invisible to
    -- the launch-arc, barrier-adjacency and pickup-burial checks).

    Spawns = {
        Blue = {
            { -186, 2, -18 },
            { -186, 2, -6 },
            { -186, 2, 6 },
            { -186, 2, 18 },
            { -194, 2, -12 },
            { -194, 2, 12 },
        },
        Red = {
            { 186, 2, -18 },
            { 186, 2, -6 },
            { 186, 2, 6 },
            { 186, 2, 18 },
            { 194, 2, -12 },
            { 194, 2, 12 },
        },
    },

    -- Exactly three. FinalePlan.create rejects any other count whenever `Finale` exists, and
    -- ConvergenceService then aborts the match before the map even loads. Validate never
    -- inspects the count, so that failure would ship CI-green.
    Objectives = {
        {
            Id = "bridge",
            Name = "Trestle Bridge",
            pos = { 0, 12, -76 },
            radius = 16,
            halfHeight = 5,
            Phases = { 1, 2, 3 },
        },
        { Id = "basin", Name = "The Basin", pos = { 0, -1, 0 }, radius = 20, halfHeight = 9, Phases = { 1, 2, 3 } },
        { Id = "delta", Name = "Cypress Delta", pos = { 0, 7, 76 }, radius = 16, halfHeight = 7, Phases = { 1, 2, 3 } },
    },
    -- With a Finale declared, FinalePlan.live overrides Phases entirely; the Phases above are
    -- authored correctly anyway so the file never reads as a half-configured static map.
    Finale = { EligibleIds = { "bridge", "basin", "delta" } },

    Vista = { pos = { -248, 70, -160 }, look = { 0, 6, -30 }, seconds = 3 },

    -- Play spans 17 studs of height (outposts at 16, basin at -1), over the DropHeight of 8,
    -- so RecoveryY, Bounds and SafePoints are mandatory rather than optional.
    RecoveryY = -12, -- 9 studs below the lake bed: wading the basin must never be lethal
    -- Deliberately wider than the walls. With SafetyAlwaysOn a Bounds box that clips real
    -- ground kills real players; the walls and Barrier do the containment, Bounds only
    -- catches someone who has left the world entirely.
    Bounds = { min = { -212, -18, -112 }, max = { 212, 130, 112 } },
    -- Honest, not lazy: the water is two studs deep and wadeable, and the space under the
    -- bridge is open water and open ground. There are no voids and no illegal pockets.
    InvalidRegions = {},
    SafeRegions = {},
    SafePoints = {
        { name = "Blue Staging", pos = { -176, 1, 0 } },
        { name = "Red Staging", pos = { 176, 1, 0 } },
        { name = "Bridge Deck", pos = { 0, 13, -76 } },
        { name = "North Shore", pos = { 0, 1, -96 } },
        { name = "West Bank", pos = { -66, 1, 0 } },
        { name = "East Bank", pos = { 66, 1, 0 } },
        { name = "Delta Landing", pos = { 0, 8, 76 } },
    },
    -- Closed box with overlapping corners: N/S reach x +-208 past the W/E segments at
    -- +-206.5, and W/E reach z +-104 past N/S at +-103.5. Height 24 is sized by jump reach
    -- from the bridge deck (y 12, 9.75 studs away, an R15 jump reaches ~19.2) and is also the
    -- maximum that still passes Validate's adjacency rule.
    Barrier = {
        { pos = { 0, 12, -103.5 }, size = { 416, 24, 1.5 } },
        { pos = { 0, 12, 103.5 }, size = { 416, 24, 1.5 } },
        { pos = { -206.5, 12, 0 }, size = { 1.5, 24, 208 } },
        { pos = { 206.5, 12, 0 }, size = { 1.5, 24, 208 } },
    },

    Terrain = {
        GroundMaterial = Enum.Material.LeafyGrass,
        GroundColor = Color3.fromRGB(88, 122, 68),
        -- Water appearance. Without the Terrain.Water hook in MapService the basin renders
        -- as the hard-coded tropical blue, which fights the whole art brief.
        Water = {
            Color = Color3.fromRGB(74, 108, 62),
            Transparency = 0.35,
            Reflectance = 0.2,
            WaveSize = 0.02,
        },
        -- Deliberately empty. makeTree/scatterTrees plant every trunk at y = 0 with no
        -- terrain awareness, and Validate models hills as nothing, so any hill inside the
        -- scatter box is a guaranteed buried-tree bug that no gate reports.
        Hills = {},
        Mountains = {
            { 0, -120, -640, 220 },
            { 0, -120, 640, 220 },
            { -640, -130, 0, 230 },
            { 640, -130, 0, 230 },
        },
        -- buildTerrain carves with FillCylinder at math.max(rx, rz) and discards the smaller
        -- radius, so an ellipse is not expressible. rx == rz is authored honestly rather than
        -- copying Forest's {0,0,22,14,3}, which has always built a 22-radius circle.
        -- Result: air carve y 0..-3, water fill topping out at y = -1, bed at y = -3.
        -- Depth 3 keeps an R15's root above the surface, so Swimming never triggers.
        Lake = { 0, -28, 56, 56, 3 },
    },

    -- applyLighting reads ClockTime, Brightness, Ambient, OutdoorAmbient, FogColor, FogStart,
    -- FogEnd, SunRays, Bloom and all four Atmosphere fields with NO nil guard: omitting any
    -- throws inside Build, which MapService:Load pcalls into a silent fallback to another map.
    -- Atmosphere.Decay is deliberately absent - applyLighting hard-codes it three lines later.
    Environment = {
        ClockTime = 12.6,
        Brightness = 2.3,
        Ambient = Color3.fromRGB(112, 128, 100),
        OutdoorAmbient = Color3.fromRGB(150, 170, 136),
        FogColor = Color3.fromRGB(198, 216, 186),
        FogStart = 300,
        FogEnd = 1250,
        Atmosphere = { Density = 0.28, Haze = 1.1, Glare = 0.06, Color = Color3.fromRGB(200, 216, 188) },
        SunRays = 0.06,
        Bloom = 0.35,
        -- The swamp's green comes from Ambient/OutdoorAmbient/Atmosphere.Color, never from a
        -- negative Saturation or a green Tint: ColorCorrection grades the team highlights and
        -- the neon objective rings too.
        Saturation = 0.16,
        Contrast = 0.12,
        Tint = Color3.fromRGB(252, 255, 250),
    },

    -- applyPalette pulls seven magic keys (Rock, RockEdge, Bark, Needles, Wood, Marker,
    -- Mountain); placePiece reads HullDark for steam. Omit one and it silently inherits the
    -- PREVIOUS map's colour, because PALETTE is module state.
    Palette = {
        Rock = Color3.fromRGB(208, 200, 178),
        RockEdge = Color3.fromRGB(255, 152, 48),
        Bark = Color3.fromRGB(96, 78, 58),
        Needles = { Color3.fromRGB(54, 152, 86), Color3.fromRGB(40, 130, 84), Color3.fromRGB(78, 170, 90) },
        Wood = Color3.fromRGB(128, 106, 78),
        Marker = Color3.fromRGB(255, 234, 72),
        Mountain = Color3.fromRGB(126, 148, 128),
        HullDark = Color3.fromRGB(44, 48, 44),
        -- block colour keys referenced by name below
        Plank = Color3.fromRGB(176, 138, 88),
        Timber = Color3.fromRGB(124, 96, 62),
        Stone = Color3.fromRGB(148, 148, 134),
        Bunker = Color3.fromRGB(122, 124, 112),
        Steel = Color3.fromRGB(128, 136, 140),
        Silt = Color3.fromRGB(88, 80, 56),
        Moss = Color3.fromRGB(46, 96, 58),
    },

    -- ===== Centre line (x = 0, placed once) =====
    -- No `light` and no `beacon` anywhere on this map: makePart never sets CanQuery = false,
    -- so a light anchor and a beacon ball are both invisible bullet sponges, and neither kind
    -- accepts `decor`. Deck lighting is carried by Environment alone.
    Center = {
        -- Trestle Bridge deck: top y = 12, x +-58, z -93..-59. Wide enough to carry the
        -- 16-stud capture ring with a stud of margin at each end.
        { name = "BridgeDeck", pos = { 0, 11, -76 }, size = { 116, 2, 34 }, color = "Plank", material = "WoodPlanks" },
        -- Row A stands in the water (bed at y = -3), row B on grade north of the lake.
        { name = "PylonA0", pos = { 0, 3.5, -70 }, size = { 3, 13, 3 }, color = "Timber", material = "Wood" },
        { name = "PylonB0", pos = { 0, 5, -86 }, size = { 3, 10, 3 }, color = "Timber", material = "Wood" },
        -- Plank causeway wading south out of the bridge shadow, top y = 0.1
        { name = "Causeway", pos = { 0, -0.4, -22 }, size = { 6, 1, 88 }, color = "Plank", material = "WoodPlanks" },
        -- Cypress Delta landing: solid, top y = 7
        {
            name = "DeltaLanding",
            pos = { 0, 3.5, 76 },
            size = { 40, 7, 36 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "DeltaStair1",
            pos = { 0, 0.875, 47.5 },
            size = { 14, 1.75, 3 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "DeltaStair2",
            pos = { 0, 1.75, 50.5 },
            size = { 14, 3.5, 3 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "DeltaStair3",
            pos = { 0, 2.625, 53.5 },
            size = { 14, 5.25, 3 },
            color = "Plank",
            material = "WoodPlanks",
        },
        { name = "DeltaStair4", pos = { 0, 3.5, 56.5 }, size = { 14, 7, 3 }, color = "Plank", material = "WoodPlanks" },
        -- log size is {ignored, diameter, length} and pos is the BASE
        { kind = "log", name = "DeltaTrunk", pos = { 0, 7, 76 }, size = { 5, 3, 26 }, rot = { 0, 0, 0 } },
        -- mud flats: decor, so they stop no bullets and occlude no bot LOS
        {
            name = "FlatN",
            pos = { 0, 0.15, -94 },
            size = { 80, 0.3, 18 },
            color = "Silt",
            material = "Mud",
            decor = true,
            shadow = false,
        },
        {
            name = "FlatS",
            pos = { 0, 0.15, 36 },
            size = { 90, 0.3, 16 },
            color = "Silt",
            material = "Mud",
            decor = true,
            shadow = false,
        },
        -- North and south halves of the same revetment; the west/east runs are mirrored.
        { name = "RevetN", pos = { 0, 1, -101 }, size = { 404, 2, 3 }, color = "Timber", material = "Wood" },
        { name = "RevetS", pos = { 0, 1, 101 }, size = { 404, 2, 3 }, color = "Timber", material = "Wood" },
        { kind = "marker", name = "DeckLine", pos = { 0, 12, -76 }, size = { 40, 0.3, 1.5 } },
    },

    -- ===== Mirrored (authored once at negative X = the Red copy) =====
    Mirrored = {
        -- --- Trestle Bridge substructure ---
        -- Row A (z = -70): lake half-width there is 37.04, so x 14 and 28 stand on the bed
        -- (base -3, height 13) and x 44, 56 stand on grade (base 0, height 10).
        { name = "PylonA14", pos = { -14, 3.5, -70 }, size = { 3, 13, 3 }, color = "Timber", material = "Wood" },
        { name = "PylonA28", pos = { -28, 3.5, -70 }, size = { 3, 13, 3 }, color = "Timber", material = "Wood" },
        { name = "PylonA44", pos = { -44, 5, -70 }, size = { 3, 10, 3 }, color = "Timber", material = "Wood" },
        { name = "PylonA56", pos = { -56, 5, -70 }, size = { 3, 10, 3 }, color = "Timber", material = "Wood" },
        -- Row B (z = -86) is entirely north of the lake, which ends at z = -84.
        { name = "PylonB14", pos = { -14, 5, -86 }, size = { 3, 10, 3 }, color = "Timber", material = "Wood" },
        { name = "PylonB28", pos = { -28, 5, -86 }, size = { 3, 10, 3 }, color = "Timber", material = "Wood" },
        { name = "PylonB44", pos = { -44, 5, -86 }, size = { 3, 10, 3 }, color = "Timber", material = "Wood" },
        { name = "PylonB56", pos = { -56, 5, -86 }, size = { 3, 10, 3 }, color = "Timber", material = "Wood" },
        -- Dry-land ramp onto the deck. Solved from the junction constraint including slab
        -- thickness: cy = H - (L/2)sin0 - (t/2)cos0. High-end top face lands on 12.0000 and
        -- the low end beds in at -0.0552, so there is no lip at either junction.
        -- L/rise = 2.281 >= 2.2, and rot[3] = 26 is inside Validate's 20-32 ramp window.
        {
            name = "BridgeRampW",
            pos = { -70.052, 5.343, -76 },
            size = { 27.5, 1.4, 12 },
            rot = { 0, 0, 26 },
            color = "Plank",
            material = "WoodPlanks",
        },
        -- Basin Stair: ten stepped piers climbing out of the water onto the deck's south
        -- edge, so the wet district feeds the elevated one. 1.5-stud risers, no rotation.
        {
            name = "BasinStep1",
            pos = { -22, -2.25, -21 },
            size = { 10, 1.5, 4 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "BasinStep2",
            pos = { -22, -1.5, -25 },
            size = { 10, 3, 4 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "BasinStep3",
            pos = { -22, -0.75, -29 },
            size = { 10, 4.5, 4 },
            color = "Plank",
            material = "WoodPlanks",
        },
        { name = "BasinStep4", pos = { -22, 0, -33 }, size = { 10, 6, 4 }, color = "Plank", material = "WoodPlanks" },
        {
            name = "BasinStep5",
            pos = { -22, 0.75, -37 },
            size = { 10, 7.5, 4 },
            color = "Plank",
            material = "WoodPlanks",
        },
        { name = "BasinStep6", pos = { -22, 1.5, -41 }, size = { 10, 9, 4 }, color = "Plank", material = "WoodPlanks" },
        {
            name = "BasinStep7",
            pos = { -22, 2.25, -45 },
            size = { 10, 10.5, 4 },
            color = "Plank",
            material = "WoodPlanks",
        },
        { name = "BasinStep8", pos = { -22, 3, -49 }, size = { 10, 12, 4 }, color = "Plank", material = "WoodPlanks" },
        {
            name = "BasinStep9",
            pos = { -22, 3.75, -53 },
            size = { 10, 13.5, 4 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "BasinStep10",
            pos = { -22, 4.5, -57 },
            size = { 10, 15, 4 },
            color = "Plank",
            material = "WoodPlanks",
        },

        -- --- Bog cover: everything tops out at y = 4 so nothing perches over the basin ---
        { kind = "rock", name = "BogRockA", pos = { -13, -3, -10 }, size = { 10, 7, 9 } },
        { kind = "rock", name = "BogRockB", pos = { -16, -3, 10 }, size = { 9, 7, 8 } },
        { kind = "stump", name = "BogKnee", pos = { -9, -3, -16 }, size = { 6, 7, 6 } },

        -- --- Cypress Delta approaches: two side ramps per team plus the centre stair ---
        {
            name = "DeltaRampW66",
            pos = { -26.927, 2.954, 66 },
            size = { 16, 1.2, 8 },
            rot = { 0, 0, 26 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "DeltaRampW86",
            pos = { -26.927, 2.954, 86 },
            size = { 16, 1.2, 8 },
            rot = { 0, 0, 26 },
            color = "Plank",
            material = "WoodPlanks",
        },
        -- stump size is {diameterX, HEIGHT, diameterZ}; its rot is ignored by the builder
        { kind = "stump", name = "DeltaStumpA", pos = { -12, 7, 66 }, size = { 5, 4, 5 } },
        { kind = "stump", name = "DeltaStumpB", pos = { -15, 7, 88 }, size = { 5, 4, 5 } },

        -- --- Corner watchtowers (photo 2). Deck top 13.2, parapet top 16.2: shoot over, ---
        -- --- not a roof. Each is entered from its own team's side only. ---
        { name = "TowerWNLeg1", pos = { -147, 6, -85 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        { name = "TowerWNLeg2", pos = { -137, 6, -85 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        { name = "TowerWNLeg3", pos = { -147, 6, -75 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        { name = "TowerWNLeg4", pos = { -137, 6, -75 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        {
            name = "TowerWNDeck",
            pos = { -142, 12.6, -80 },
            size = { 12, 1.2, 12 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "TowerWNParOut",
            pos = { -142, 14.7, -85.4 },
            size = { 12, 3, 1.2 },
            color = "Timber",
            material = "Wood",
        },
        {
            name = "TowerWNParIn",
            pos = { -142, 14.7, -74.6 },
            size = { 12, 3, 1.2 },
            color = "Timber",
            material = "Wood",
        },
        {
            name = "TowerWNParW",
            pos = { -147.4, 14.7, -80 },
            size = { 1.2, 3, 12 },
            color = "Timber",
            material = "Wood",
        },
        {
            name = "TowerWNParE",
            pos = { -136.6, 14.7, -80 },
            size = { 1.2, 3, 12 },
            color = "Timber",
            material = "Wood",
        },
        -- the sketch's vertical tick. decor, so this thin mast is not a bullet sponge above
        -- the highest perch on the map.
        {
            name = "TowerWNMast",
            pos = { -147.4, 21.2, -85.4 },
            size = { 0.6, 10, 0.6 },
            color = "Steel",
            material = "Metal",
            decor = true,
        },
        {
            name = "TowerWNRamp",
            pos = { -161.22, 5.973, -80 },
            size = { 30.1, 1.4, 8 },
            rot = { 0, 0, 26 },
            color = "Plank",
            material = "WoodPlanks",
        },
        { name = "TowerWSLeg1", pos = { -147, 6, 85 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        { name = "TowerWSLeg2", pos = { -137, 6, 85 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        { name = "TowerWSLeg3", pos = { -147, 6, 75 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        { name = "TowerWSLeg4", pos = { -137, 6, 75 }, size = { 3, 12, 3 }, color = "Timber", material = "Wood" },
        {
            name = "TowerWSDeck",
            pos = { -142, 12.6, 80 },
            size = { 12, 1.2, 12 },
            color = "Plank",
            material = "WoodPlanks",
        },
        {
            name = "TowerWSParOut",
            pos = { -142, 14.7, 85.4 },
            size = { 12, 3, 1.2 },
            color = "Timber",
            material = "Wood",
        },
        {
            name = "TowerWSParIn",
            pos = { -142, 14.7, 74.6 },
            size = { 12, 3, 1.2 },
            color = "Timber",
            material = "Wood",
        },
        {
            name = "TowerWSParW",
            pos = { -147.4, 14.7, 80 },
            size = { 1.2, 3, 12 },
            color = "Timber",
            material = "Wood",
        },
        {
            name = "TowerWSParE",
            pos = { -136.6, 14.7, 80 },
            size = { 1.2, 3, 12 },
            color = "Timber",
            material = "Wood",
        },
        {
            name = "TowerWSMast",
            pos = { -147.4, 21.2, 85.4 },
            size = { 0.6, 10, 0.6 },
            color = "Steel",
            material = "Metal",
            decor = true,
        },
        {
            name = "TowerWSRamp",
            pos = { -161.22, 5.973, 80 },
            size = { 30.1, 1.4, 8 },
            rot = { 0, 0, 26 },
            color = "Plank",
            material = "WoodPlanks",
        },

        -- --- Sightline screens: the reason no perch owns the map. All six west ---
        -- --- tower-to-objective lanes cross x = -126 inside these slabs. ---
        { name = "TowerScreenNW", pos = { -126, 11, -74 }, size = { 3, 22, 40 }, color = "Bunker", material = "Slate" },
        { name = "TowerScreenSW", pos = { -126, 11, 74 }, size = { 3, 22, 40 }, color = "Bunker", material = "Slate" },

        -- --- Bunker hide (photo 4): the sketch's capture point B, demoted from an ---
        -- --- objective and doubled onto the mirror so both teams get one. The east ---
        -- --- face is open - that is the slit, looking out over the swamp. ---
        { name = "HideBack", pos = { -84, 3, -30 }, size = { 2, 6, 16 }, color = "Stone", material = "Slate" },
        { name = "HideNorth", pos = { -77, 3, -37 }, size = { 16, 6, 2 }, color = "Stone", material = "Slate" },
        { name = "HideSouth", pos = { -77, 3, -23 }, size = { 16, 6, 2 }, color = "Stone", material = "Slate" },
        { name = "HideRoof", pos = { -77, 6.6, -30 }, size = { 18, 1.2, 18 }, color = "Timber", material = "Wood" },
        {
            name = "HideStack",
            pos = { -83, 9.7, -35 },
            size = { 1.2, 5, 1.2 },
            color = "Steel",
            material = "Metal",
            decor = true,
        },
        { kind = "steam", name = "HideSmoke", pos = { -83, 12.2, -35 } },

        -- --- Colonnade: the sketch's conifer band as 16 big named boles you can shoot ---
        -- --- between, instead of ~800 tree parts. Every one is outside the lake and ---
        -- --- outside the launch corridor. ---
        { kind = "stump", name = "Bole1", pos = { -66, 0, -96 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole2", pos = { -70, 0, -40 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole3", pos = { -64, 0, -8 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole4", pos = { -72, 0, 18 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole5", pos = { -68, 0, 64 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole6", pos = { -76, 0, 92 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole7", pos = { -100, 0, -92 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole8", pos = { -96, 0, -60 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole9", pos = { -104, 0, -20 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole10", pos = { -98, 0, 8 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole11", pos = { -102, 0, 62 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole12", pos = { -94, 0, 90 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole13", pos = { -118, 0, -70 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole14", pos = { -114, 0, 4 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole15", pos = { -116, 0, 74 }, size = { 7, 26, 7 } },
        { kind = "stump", name = "Bole16", pos = { -132, 0, -34 }, size = { 7, 26, 7 } },

        -- --- Rocks: the sketch's boulder clusters in the open flank ground ---
        { kind = "rock", name = "FlankRock1", pos = { -166, 0, -56 }, size = { 14, 7, 10 } },
        { kind = "rock", name = "FlankRock2", pos = { -152, 0, -18 }, size = { 11, 5.5, 9 } },
        { kind = "rock", name = "FlankRock3", pos = { -120, 0, -44 }, size = { 16, 8, 13 } },
        { kind = "rock", name = "FlankRock4", pos = { -128, 0, 20 }, size = { 9, 5, 8 } },
        { kind = "rock", name = "FlankRock5", pos = { -96, 0, 68 }, size = { 12, 6, 10 } },

        -- --- Canopy (photo 1) for two parts. decor + shadow = false: no bullets stopped, ---
        -- --- no bot LOS occluded, no shadow casters. ---
        {
            name = "CanopyN",
            pos = { -96, 33, -56 },
            size = { 72, 2, 88 },
            color = "Moss",
            material = "Grass",
            decor = true,
            shadow = false,
        },
        {
            name = "CanopyS",
            pos = { -96, 33, 52 },
            size = { 72, 2, 80 },
            color = "Moss",
            material = "Grass",
            decor = true,
            shadow = false,
        },

        -- --- Lane markers so routes read at a glance. rot[3] is 0 on every one, so ---
        -- --- Validate's ramp rule never fires on a thin slab. ---
        { kind = "marker", name = "DeckEdgeN", pos = { -30, 12, -91 }, size = { 56, 0.3, 1.2 } },
        { kind = "marker", name = "DeckEdgeS", pos = { -30, 12, -61 }, size = { 56, 0.3, 1.2 } },
        { kind = "marker", name = "LaneMid", pos = { -160, 0, 0 }, size = { 44, 0.3, 1.5 } },
        -- Plank landing stage under the launch target. Validate.solids no longer synthesises
        -- a TerrainGround slab, so a launch pad needs authored floor beneath its target.
        -- Kept to 10 x 10 so every corner stays inside the PadRadius 8 footprint that the
        -- arc-clearance test excludes, and 0.3 tall so the drop is 0.7 studs.
        {
            name = "PadLanding",
            pos = { -72, 0.15, 40 },
            size = { 10, 0.3, 10 },
            color = "Plank",
            material = "WoodPlanks",
        },
        -- Timber revetment marking the playable edge. It gives the Barrier something real to
        -- sit against, and it tells the player where the world stops instead of letting them
        -- walk into an invisible wall.
        { name = "RevetW", pos = { -203, 1, 0 }, size = { 3, 2, 204 }, color = "Timber", material = "Wood" },
        { kind = "marker", name = "LaneN", pos = { -150, 0, -58 }, size = { 46, 0.3, 1.5 }, rot = { 0, 22, 0 } },
        { kind = "marker", name = "LaneS", pos = { -150, 0, 58 }, size = { 46, 0.3, 1.5 }, rot = { 0, -22, 0 } },
    },

    -- Backdrop woodland only. The scatter half-extent is Size/2 - 6 = 204 and the single
    -- exclude rect clears |z| < 106, so every tree lands at |z| in [106, 204] - 2.5 studs
    -- outside the containment barrier, zero trees in play. Count 120 is 48% of the RSA
    -- packing ceiling at MinSpacing 15, so it delivers in full.
    -- No groves: makeGrove ignores MinSpacing so trunks interpenetrate, and a grove missing
    -- `count` throws inside Build, which Load pcalls into a silent fallback to another map.
    Trees = {
        Count = 120,
        MinSpacing = 15,
        Height = { 26, 44 },
        Exclude = { { 0, 0, 210, 106 } },
    },

    -- Two pure x-mirror pairs, so no Symmetry override is needed. ConvergenceService tests
    -- occupancy with a 3D sphere, not a cylinder: the deck centre is 0.20 away and a deck
    -- corner 7.07 (both in), while the ground directly below is 13.00 (out), so ground
    -- traffic cannot pollute the outpost telemetry.
    SniperOutposts = {
        { Name = "Northwest Mast", pos = { -142, 16, -80 }, radius = 10 },
        { Name = "Northeast Mast", pos = { 142, 16, -80 }, radius = 10 },
        { Name = "Southwest Mast", pos = { -142, 16, 80 }, radius = 10 },
        { Name = "Southeast Mast", pos = { 142, 16, 80 }, radius = 10 },
    },

    -- The tower pickups are what give the four screened perches a reason to exist: you climb
    -- for the weapon and must come back down to use it. No jetpack anywhere - a 3.5 s tank at
    -- Thrust 42 is a 147-stud climb against boundary walls that only span y = 0..48, and with
    -- no jetpack entry Validate's Bounds-ceiling rule never runs at all.
    Pickups = {
        { kind = "weapon", weapon = "Sniper", pos = { -142, 14.4, -80 }, respawn = 75, duration = 45 },
        { kind = "weapon", weapon = "Sniper", pos = { 142, 14.4, -80 }, respawn = 75, duration = 45 },
        { kind = "weapon", weapon = "Shotgun", pos = { -142, 14.4, 80 }, respawn = 60, duration = 45 },
        { kind = "weapon", weapon = "Shotgun", pos = { 142, 14.4, 80 }, respawn = 60, duration = 45 },
        { kind = "speed", pos = { -106, 1.5, -8 } },
        { kind = "speed", pos = { 106, 1.5, -8 } },
        { kind = "weapon", weapon = "Minigun", pos = { 0, 1.5, -96 }, respawn = 90, duration = 40 },
    },

    -- The map's single route asymmetry: 3.2 s faster to the Delta for the team willing to pay
    -- a fixed, audible, pre-aimable 0.65 s arc between two known coordinates. Both pad and
    -- target are 99+ studs from the lake centre (radius 56), so the landing is genuinely dry -
    -- which Validate cannot confirm, since its flat terrain slab has no hole for the lake.
    --
    -- INVARIANT, load-bearing: no Center or Mirrored solid whose AABB bottom is below y = 20,
    -- and no terrain feature, may occupy z in [26, 54] for |x| in [62, 150]. Every colonnade
    -- z-value, both screens, all five rocks and both canopy slabs were chosen against it.
    LaunchPads = {
        { pos = { -140, 0.3, 40 }, target = { -72, 1, 40 }, vy = 62, size = 8 },
        { pos = { 140, 0.3, 40 }, target = { 72, 1, 40 }, vy = 62, size = 8 },
    },
}

return map
