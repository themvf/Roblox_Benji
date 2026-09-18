-- Aircraft carrier greybox for Convergence. Three objectives, each a different fight:
--   Flight Deck  long sightlines, open movement           (phase 1 only; closes first)
--   Hangar       close quarters under the deck            (phases 1-2)
--   Bridge       vertical, defensible island tower        (phases 1-3; the final fight)
-- Red spawns at the bow (-X), Blue at the stern (+X). The ship runs along X.
-- Everything in Mirrored is duplicated across X so both ends are equal.
-- Heights: hangar floor y=0, flight deck y=16, bridge decks y=24 / 32 / 40.
return {
    Name = "Carrier",
    Size = 340, -- boundary walls
    WallHeight = 80,
    Seed = 7,

    Spawns = {
        Red = {
            { -140, 18, -10 },
            { -140, 18, 0 },
            { -140, 18, 10 },
            { -150, 18, -5 },
            { -150, 18, 5 },
            { -145, 18, 15 },
        },
        Blue = { { 140, 18, -10 }, { 140, 18, 0 }, { 140, 18, 10 }, { 150, 18, -5 }, { 150, 18, 5 }, { 145, 18, 15 } },
    },

    -- Objectives for ConvergenceService. Phases = which phases the zone is live in.
    Objectives = {
        { Name = "Flight Deck", pos = { 0, 16, -12 }, radius = 16, Phases = { 1 } },
        { Name = "Hangar", pos = { 0, 0, 0 }, radius = 14, Phases = { 1, 2 } },
        { Name = "Bridge", pos = { 0, 32, 42 }, radius = 10, Phases = { 1, 2, 3 } },
    },

    -- Cinematic but readable: overcast sea, cool light, warm hazard accents.
    Environment = {
        ClockTime = 15.5,
        Brightness = 1.8,
        Ambient = Color3.fromRGB(110, 120, 135),
        OutdoorAmbient = Color3.fromRGB(140, 150, 165),
        FogColor = Color3.fromRGB(190, 200, 215),
        FogStart = 250,
        FogEnd = 900,
        Atmosphere = { Density = 0.3, Haze = 1.2, Glare = 0.1, Color = Color3.fromRGB(200, 208, 220) },
        SunRays = 0.05,
        Bloom = 0.3,
        Saturation = -0.05,
        Contrast = 0.1,
        Tint = Color3.fromRGB(235, 240, 250),
    },

    Palette = {
        Deck = Color3.fromRGB(70, 75, 82), -- dark non-slip deck
        DeckLine = Color3.fromRGB(240, 220, 90), -- painted markings
        Hull = Color3.fromRGB(120, 128, 138),
        Hangar = Color3.fromRGB(95, 100, 108),
        Island = Color3.fromRGB(150, 156, 165),
        Hazard = Color3.fromRGB(255, 140, 40), -- catwalk rails, elevator edges
        Crate = Color3.fromRGB(90, 110, 80),
        Marker = Color3.fromRGB(255, 230, 80),
        Mountain = Color3.fromRGB(150, 165, 185),
    },

    -- Open sea instead of ground
    Terrain = {
        GroundMaterial = Enum.Material.Water,
        Sea = true,
        SeaLevel = -30,
        Hills = {},
        Mountains = {},
    },

    -- Structure that is the same for both ends (placed once)
    Center = {
        -- hull and hangar box
        { kind = "block", name = "HullBottom", pos = { 0, -8, 0 }, size = { 300, 4, 90 }, color = "Hull" },
        { kind = "block", name = "HangarFloor", pos = { 0, -1, 0 }, size = { 220, 2, 70 }, color = "Hangar" },
        { kind = "block", name = "HangarWallN", pos = { 0, 7, -34 }, size = { 220, 16, 2 }, color = "Hangar" },
        { kind = "block", name = "HangarWallS", pos = { 0, 7, 34 }, size = { 220, 16, 2 }, color = "Hangar" },
        -- flight deck slab with two elevator holes left open (handled by deck pieces below)
        { kind = "block", name = "DeckMid", pos = { 0, 15, 0 }, size = { 80, 2, 90 }, color = "Deck" },
        { kind = "block", name = "DeckLineMid", pos = { 0, 16.05, 0 }, size = { 60, 0.1, 2 }, color = "DeckLine" },
        -- hangar interior cover: crates and a parked "aircraft" block
        { kind = "block", name = "Crate1", pos = { 0, 2, -14 }, size = { 8, 4, 6 }, color = "Crate" },
        { kind = "block", name = "Crate2", pos = { 0, 2, 14 }, size = { 8, 4, 6 }, color = "Crate" },
        { kind = "block", name = "Aircraft", pos = { 0, 3, 0 }, size = { 18, 6, 10 }, color = "Island" },
        -- bridge island: three stacked decks on the starboard side, above the deck
        { kind = "block", name = "IslandBase", pos = { 0, 20, 42 }, size = { 30, 8, 14 }, color = "Island" },
        { kind = "block", name = "IslandDeck2", pos = { 0, 28, 42 }, size = { 26, 8, 12 }, color = "Island" },
        { kind = "block", name = "IslandTop", pos = { 0, 36.5, 42 }, size = { 20, 1, 12 }, color = "Island" },
        { kind = "block", name = "IslandRailN", pos = { 0, 38.5, 36.5 }, size = { 20, 3, 0.5 }, color = "Hazard" },
        { kind = "block", name = "IslandRailS", pos = { 0, 38.5, 47.5 }, size = { 20, 3, 0.5 }, color = "Hazard" },
        -- landing on deck 2 (bridge objective floor) with cover
        { kind = "block", name = "BridgeFloor", pos = { 0, 32.5, 42 }, size = { 26, 1, 12 }, color = "Deck" },
        { kind = "block", name = "BridgeCover1", pos = { -6, 34.5, 42 }, size = { 2, 3, 6 }, color = "Crate" },
        { kind = "block", name = "BridgeCover2", pos = { 6, 34.5, 42 }, size = { 2, 3, 6 }, color = "Crate" },
        -- radar mast for silhouette
        { kind = "block", name = "Mast", pos = { 0, 48, 46 }, size = { 2, 22, 2 }, color = "Island" },
    },

    -- Bow half (negative X); mirrored to the stern
    Mirrored = {
        -- deck sections either side of the elevator gap
        { kind = "block", name = "DeckEnd", pos = { -110, 15, 0 }, size = { 80, 2, 90 }, color = "Deck" },
        { kind = "block", name = "DeckLine", pos = { -110, 16.05, 0 }, size = { 70, 0.1, 2 }, color = "DeckLine" },
        -- elevator: open hole between DeckMid and DeckEnd at x=-55..-40 on the port side, with a ramp down
        { kind = "block", name = "DeckFillS", pos = { -55, 15, 22 }, size = { 30, 2, 46 }, color = "Deck" },
        {
            kind = "block",
            name = "ElevatorRamp",
            pos = { -55, 8, -18 },
            size = { 30, 1, 20 },
            color = "Hazard",
            rot = { 28, 0, 0 },
        },
        {
            kind = "block",
            name = "ElevatorRail",
            pos = { -55, 16.5, -30.5 },
            size = { 30, 1.5, 0.5 },
            color = "Hazard",
        },
        -- deck cover: parked aircraft blocks and tow tractors
        { kind = "block", name = "DeckJet1", pos = { -85, 18.5, -25 }, size = { 14, 5, 8 }, color = "Island" },
        {
            kind = "block",
            name = "DeckJet2",
            pos = { -70, 18.5, 20 },
            size = { 14, 5, 8 },
            color = "Island",
            rot = { 0, 25, 0 },
        },
        { kind = "block", name = "Tractor", pos = { -35, 17.5, 30 }, size = { 5, 3, 4 }, color = "Hazard" },
        { kind = "block", name = "DeckCrate", pos = { -25, 17.5, -30 }, size = { 6, 3, 6 }, color = "Crate" },
        -- hangar end ramps down from the deck ends to the hangar (spawn -> hangar route)
        {
            kind = "block",
            name = "HangarRamp",
            pos = { -122, 7, 0 },
            size = { 36, 1, 12 },
            color = "Hazard",
            rot = { 0, 0, -25 },
        },
        { kind = "block", name = "HangarEndWall", pos = { -110, 7, 0 }, size = { 2, 16, 70 }, color = "Hangar" },
        { kind = "block", name = "HangarDoor", pos = { -109, 7, 0 }, size = { 4, 14, 14 }, color = "Hazard" },
        -- hangar cover
        { kind = "block", name = "HangarCrate1", pos = { -60, 2, -8 }, size = { 8, 4, 8 }, color = "Crate" },
        { kind = "block", name = "HangarCrate2", pos = { -40, 2, 10 }, size = { 8, 4, 8 }, color = "Crate" },
        { kind = "block", name = "HangarJet", pos = { -85, 3, 12 }, size = { 18, 6, 10 }, color = "Island" },
        -- stairs up the island from the deck (bridge route)
        {
            kind = "block",
            name = "IslandStair1",
            pos = { -22, 20, 42 },
            size = { 14, 1, 6 },
            color = "Hazard",
            rot = { 0, 0, -30 },
        },
        {
            kind = "block",
            name = "IslandStair2",
            pos = { -20, 28, 36 },
            size = { 12, 1, 5 },
            color = "Hazard",
            rot = { 0, 0, -32 },
        },
        -- catwalk along the port edge below deck level
        { kind = "block", name = "Catwalk", pos = { -80, 11, -46 }, size = { 60, 0.5, 4 }, color = "Hazard" },
        { kind = "block", name = "CatwalkRail", pos = { -80, 12.5, -48 }, size = { 60, 2.5, 0.3 }, color = "Hazard" },
        -- lane markers on the deck toward each objective
        { kind = "marker", pos = { -60, 16, -12 }, size = { 40, 0.3, 1.5 } },
    },
}
