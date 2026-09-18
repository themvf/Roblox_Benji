-- Aircraft carrier for Convergence. "Battlefield atmosphere, Roblox readability, exaggerated military silhouette."
-- Three objectives, each a different fight:
--   Flight Deck  long sightlines, open movement           (phase 1 only; closes first)
--   Hangar       close quarters under the deck            (phases 1-2)
--   Bridge       vertical, defensible island tower        (phases 1-3; the final fight)
-- Red spawns at the bow (-X), Blue at the stern (+X). The ship runs along X. Island is starboard (+Z).
-- Heights: hangar floor y=0, flight deck y=16, bridge decks y=24 / 32 / 40.
return {
    Name = "Carrier",
    Size = 340,
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

    Objectives = {
        { Name = "Flight Deck", pos = { 0, 16, -12 }, radius = 16, Phases = { 1 } },
        { Name = "Hangar", pos = { 0, 0, 0 }, radius = 14, Phases = { 1, 2 } },
        { Name = "Bridge", pos = { 0, 32, 42 }, radius = 10, Phases = { 1, 2, 3 } },
    },

    -- Hero view on entry: jets, ocean, island, the deck stretching away
    Vista = { pos = { -175, 60, -95 }, look = { 20, 20, 20 }, seconds = 2.5 },

    -- Signature event: sirens, the blast shield rises, a jet launch makes the catapult strip lethal.
    -- Generic shape: ConvergenceService fires events by phase; MapService renders them.
    Events = {
        {
            Name = "Jet Launch",
            TriggerPhase = 2, -- fires when phase 2 begins (flight deck just closed)
            WarningSeconds = 8,
            DurationSeconds = 25,
            Banner = "JET LAUNCH  CLEAR THE CATAPULT",
            Sound = "upload:Siren",
            Region = { pos = { -40, 22, -12 }, size = { 150, 14, 22 } }, -- lethal box over the port catapult strip
            Shield = { pos = { 30, 16.5, -12 }, size = { 2, 0.5, 22 }, rise = 6 }, -- jet blast deflector
            Beacons = true,
        },
    },

    -- Late afternoon under an approaching storm: dramatic sky, wet steel, warm hazard lights read against it.
    Environment = {
        ClockTime = 17.4,
        Brightness = 2.0,
        Ambient = Color3.fromRGB(95, 105, 125),
        OutdoorAmbient = Color3.fromRGB(125, 135, 155),
        FogColor = Color3.fromRGB(165, 175, 195),
        FogStart = 220,
        FogEnd = 800,
        Atmosphere = {
            Density = 0.36,
            Haze = 1.8,
            Glare = 0.25,
            Color = Color3.fromRGB(210, 200, 190),
            Decay = Color3.fromRGB(90, 95, 110),
        },
        SunRays = 0.12,
        Bloom = 0.35,
        Saturation = -0.08,
        Contrast = 0.14,
        Tint = Color3.fromRGB(240, 236, 232),
    },

    -- Restrained military palette; bright colour only for gameplay information
    Palette = {
        Deck = Color3.fromRGB(58, 62, 70),
        DeckLine = Color3.fromRGB(235, 225, 190),
        DeckStrip = Color3.fromRGB(240, 215, 80),
        Hull = Color3.fromRGB(108, 116, 128),
        HullDark = Color3.fromRGB(70, 76, 88),
        Hangar = Color3.fromRGB(82, 88, 98),
        Island = Color3.fromRGB(140, 146, 156),
        Steel = Color3.fromRGB(120, 124, 132),
        Hazard = Color3.fromRGB(255, 150, 40),
        Warning = Color3.fromRGB(255, 60, 50),
        Crate = Color3.fromRGB(88, 104, 78),
        Jet = Color3.fromRGB(96, 102, 112),
        Missile = Color3.fromRGB(225, 225, 230),
        Marker = Color3.fromRGB(255, 230, 80),
        Mountain = Color3.fromRGB(120, 130, 150),
    },

    Terrain = {
        GroundMaterial = Enum.Material.Water,
        Sea = true,
        SeaLevel = -30,
        Hills = {},
        Mountains = { { 0, -60, -900, 260 }, { -500, -80, -850, 220 }, { 520, -70, -880, 240 } }, -- distant coastline
    },

    Center = {
        -- hull
        { kind = "block", name = "HullBottom", pos = { 0, -8, 0 }, size = { 300, 4, 90 }, color = "HullDark" },
        { kind = "block", name = "HullSideN", pos = { 0, 4, -46 }, size = { 300, 24, 2 }, color = "Hull" },
        { kind = "block", name = "HullSideS", pos = { 0, 4, 46 }, size = { 300, 24, 2 }, color = "Hull" },
        -- hangar
        { kind = "block", name = "HangarFloor", pos = { 0, -1, 0 }, size = { 220, 2, 70 }, color = "Hangar" },
        { kind = "block", name = "HangarWallN", pos = { 0, 7, -34 }, size = { 220, 16, 2 }, color = "Hangar" },
        { kind = "block", name = "HangarWallS", pos = { 0, 7, 34 }, size = { 220, 16, 2 }, color = "Hangar" },
        { kind = "light", name = "HangarLight1", pos = { 0, 13, 0 }, color = "DeckLine", range = 60, brightness = 1.5 },
        -- flight deck, angled landing strip markings
        { kind = "block", name = "DeckMid", pos = { 0, 15, 0 }, size = { 80, 2, 90 }, color = "Deck" },
        {
            kind = "block",
            name = "StripCenter",
            pos = { 0, 16.06, 8 },
            size = { 60, 0.1, 1.5 },
            color = "DeckLine",
            rot = { 0, -12, 0 },
        },
        {
            kind = "block",
            name = "StripEdgeN",
            pos = { 0, 16.06, -2 },
            size = { 60, 0.1, 0.8 },
            color = "DeckStrip",
            rot = { 0, -12, 0 },
        },
        {
            kind = "block",
            name = "StripEdgeS",
            pos = { 0, 16.06, 18 },
            size = { 60, 0.1, 0.8 },
            color = "DeckStrip",
            rot = { 0, -12, 0 },
        },
        -- arresting cables across the strip
        { kind = "block", name = "Cable1", pos = { -10, 16.08, 8 }, size = { 0.3, 0.05, 30 }, color = "Steel" },
        { kind = "block", name = "Cable2", pos = { 0, 16.08, 8 }, size = { 0.3, 0.05, 30 }, color = "Steel" },
        { kind = "block", name = "Cable3", pos = { 10, 16.08, 8 }, size = { 0.3, 0.05, 30 }, color = "Steel" },
        -- hangar cover
        { kind = "block", name = "Crate1", pos = { 0, 2, -14 }, size = { 8, 4, 6 }, color = "Crate" },
        { kind = "block", name = "Crate2", pos = { 0, 2, 14 }, size = { 8, 4, 6 }, color = "Crate" },
        { kind = "jet", name = "HangarJetMid", pos = { 0, 0, 0 }, rot = { 0, 90, 0 } },
        { kind = "block", name = "MissileRack", pos = { -14, 1.5, -24 }, size = { 10, 3, 3 }, color = "Missile" },
        -- island tower (starboard): base, deck 2 (bridge objective), top, mast, radar
        { kind = "block", name = "IslandBase", pos = { 0, 20, 42 }, size = { 30, 8, 14 }, color = "Island" },
        { kind = "block", name = "IslandDeck2", pos = { 0, 28, 42 }, size = { 26, 8, 12 }, color = "Island" },
        { kind = "block", name = "BridgeFloor", pos = { 0, 32.5, 42 }, size = { 26, 1, 12 }, color = "Deck" },
        { kind = "block", name = "BridgeCover1", pos = { -6, 34.5, 42 }, size = { 2, 3, 6 }, color = "Crate" },
        { kind = "block", name = "BridgeCover2", pos = { 6, 34.5, 42 }, size = { 2, 3, 6 }, color = "Crate" },
        { kind = "block", name = "BridgeWindows", pos = { 0, 35, 36.2 }, size = { 24, 2.5, 0.4 }, color = "HullDark" },
        { kind = "block", name = "IslandTop", pos = { 0, 36.5, 42 }, size = { 20, 1, 12 }, color = "Island" },
        { kind = "block", name = "IslandRailN", pos = { 0, 38.5, 36.5 }, size = { 20, 3, 0.5 }, color = "Hazard" },
        { kind = "block", name = "IslandRailS", pos = { 0, 38.5, 47.5 }, size = { 20, 3, 0.5 }, color = "Hazard" },
        { kind = "block", name = "Mast", pos = { 0, 50, 46 }, size = { 2, 26, 2 }, color = "Steel" },
        {
            kind = "block",
            name = "RadarDish",
            pos = { 0, 64, 46 },
            size = { 10, 0.6, 3 },
            color = "Steel",
            rot = { 0, 0, 15 },
        },
        {
            kind = "block",
            name = "RadarArm",
            pos = { 4, 58, 46 },
            size = { 6, 0.4, 0.4 },
            color = "Steel",
            rot = { 0, 0, 40 },
        },
        { kind = "beacon", name = "MastBeacon", pos = { 0, 63.5, 46 }, color = "Warning" },
        {
            kind = "light",
            name = "BridgeLight",
            pos = { 0, 35.5, 42 },
            color = "DeckLine",
            range = 30,
            brightness = 1.2,
        },
        -- jet blast deflector at the catapult end (the event raises it)
        { kind = "block", name = "BlastShield", pos = { 30, 16.5, -12 }, size = { 2, 0.5, 22 }, color = "Hazard" },
    },

    Mirrored = {
        -- deck ends with an elevator cutout on the port side
        { kind = "block", name = "DeckEnd", pos = { -110, 15, 0 }, size = { 80, 2, 90 }, color = "Deck" },
        { kind = "block", name = "DeckFillS", pos = { -55, 15, 22 }, size = { 30, 2, 46 }, color = "Deck" },
        {
            kind = "elevator",
            name = "Elevator",
            pos = { -55, 15, -18 },
            size = { 28, 1.5, 22 },
            low = 0.5,
            high = 15,
            period = 14,
        },
        {
            kind = "block",
            name = "ElevatorRail",
            pos = { -55, 16.5, -30.5 },
            size = { 30, 1.5, 0.5 },
            color = "Hazard",
        },
        { kind = "beacon", name = "ElevatorBeacon", pos = { -41, 17.5, -30 }, color = "Hazard" },
        -- angled strip continues, deck numbers
        { kind = "block", name = "BowNumber", pos = { -135, 16.06, 0 }, size = { 12, 0.1, 8 }, color = "DeckLine" },
        -- big props: parked jets, tow tractor, fuel cart, crates
        { kind = "jet", name = "DeckJet1", pos = { -88, 16, -28 }, rot = { 0, 20, 0 } },
        { kind = "jet", name = "DeckJet2", pos = { -68, 16, 24 }, rot = { 0, -30, 0 } },
        { kind = "jet", name = "DeckJet3", pos = { -118, 16, 26 }, rot = { 0, 10, 0 } },
        { kind = "block", name = "Tractor", pos = { -35, 17.5, 30 }, size = { 5, 3, 4 }, color = "Hazard" },
        { kind = "block", name = "FuelCart", pos = { -25, 17.5, -30 }, size = { 6, 3, 4 }, color = "Warning" },
        { kind = "block", name = "DeckCrates", pos = { -100, 17.5, -8 }, size = { 6, 3, 10 }, color = "Crate" },
        -- catwalks along both edges below deck level, with rails
        { kind = "block", name = "CatwalkN", pos = { -80, 12, -49 }, size = { 70, 0.5, 5 }, color = "Steel" },
        {
            kind = "block",
            name = "CatwalkRailN",
            pos = { -80, 13.5, -51.3 },
            size = { 70, 2.5, 0.3 },
            color = "Hazard",
        },
        { kind = "block", name = "CatwalkS", pos = { -80, 12, 49 }, size = { 70, 0.5, 5 }, color = "Steel" },
        { kind = "block", name = "CatwalkRailS", pos = { -80, 13.5, 51.3 }, size = { 70, 2.5, 0.3 }, color = "Hazard" },
        {
            kind = "block",
            name = "CatwalkStairN",
            pos = { -44, 14, -47 },
            size = { 8, 0.5, 5 },
            color = "Steel",
            rot = { 0, 0, -28 },
        },
        -- hangar end: ramp down from the deck end, door frame
        {
            kind = "block",
            name = "HangarRamp",
            pos = { -122, 7, 0 },
            size = { 36, 1, 12 },
            color = "Steel",
            rot = { 0, 0, -25 },
        },
        { kind = "block", name = "HangarEndWall", pos = { -110, 7, 0 }, size = { 2, 16, 70 }, color = "Hangar" },
        { kind = "block", name = "HangarDoor", pos = { -109, 7, 0 }, size = { 4, 14, 14 }, color = "Hazard" },
        {
            kind = "light",
            name = "HangarLight2",
            pos = { -60, 13, 0 },
            color = "DeckLine",
            range = 60,
            brightness = 1.5,
        },
        -- hangar cover
        { kind = "block", name = "HangarCrate1", pos = { -60, 2, -8 }, size = { 8, 4, 8 }, color = "Crate" },
        { kind = "block", name = "HangarCrate2", pos = { -40, 2, 10 }, size = { 8, 4, 8 }, color = "Crate" },
        { kind = "jet", name = "HangarJet", pos = { -85, 0, 12 }, rot = { 0, 100, 0 } },
        -- maintenance corridor along the starboard hangar wall (limited flank)
        { kind = "block", name = "CorridorWall", pos = { -60, 5, 28 }, size = { 80, 12, 1 }, color = "HullDark" },
        { kind = "block", name = "CorridorDoor1", pos = { -95, 4, 28 }, size = { 6, 9, 1.2 }, color = "Hazard" },
        { kind = "block", name = "CorridorDoor2", pos = { -25, 4, 28 }, size = { 6, 9, 1.2 }, color = "Hazard" },
        -- island stairs from the deck (bridge route)
        {
            kind = "block",
            name = "IslandStair1",
            pos = { -22, 20, 42 },
            size = { 14, 1, 6 },
            color = "Steel",
            rot = { 0, 0, -30 },
        },
        {
            kind = "block",
            name = "IslandStair2",
            pos = { -20, 28, 36 },
            size = { 12, 1, 5 },
            color = "Steel",
            rot = { 0, 0, -32 },
        },
        -- lane markers toward the deck objective
        { kind = "marker", pos = { -60, 16, -12 }, size = { 40, 0.3, 1.5 } },
    },
}
