-- Aircraft Carrier, Map Design Specification v1.
-- "Battlefield atmosphere, Roblox readability, arcade spectacle."
-- Layers: core combat (deck / hangar / island / catwalks / corridor / cover / sniper outposts / launch pads),
-- living world (flyovers, fleet, lights, steam, radar), signature spectacle (jet-launch hazard, kraken).
-- Red spawns at the bow (-X), Blue at the stern (+X). Island is starboard (+Z). Heights: hangar 0, deck 16, bridge 32.
return {
    Name = "Carrier",
    Size = 340,
    WallHeight = 80,
    Seed = 7,
    ShadowY = 16.2, -- deck height, used by flyover shadows

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

    Vista = { pos = { -175, 60, -95 }, look = { 20, 20, 20 }, seconds = 2.5 },

    -- S9 sniper outposts (telemetry: occupancy + kills from these)
    SniperOutposts = {
        { Name = "Island Roof", pos = { 0, 38, 42 }, radius = 9 },
        { Name = "Stern Overlook", pos = { 128, 24, -44 }, radius = 6 },
    },

    -- S11-S13 pickups: 1 special per major area, long timers, visible pads
    Pickups = {
        { kind = "weapon", weapon = "Sniper", pos = { 8, 37.5, 42 }, respawn = 75, duration = 45 }, -- island roof
        { kind = "weapon", weapon = "Shotgun", pos = { -20, 1, -20 }, respawn = 60, duration = 45 }, -- hangar
        { kind = "weapon", weapon = "Minigun", pos = { 0, 17, 30 }, respawn = 90, duration = 40 }, -- central deck
        { kind = "speed", pos = { -80, 12.8, -49 } }, -- port catwalk
        { kind = "speed", pos = { 80, 12.8, 49 } }, -- starboard catwalk
        { kind = "speed", pos = { -60, 1, 24 } }, -- maintenance corridor
        { kind = "speed", pos = { 60, 1, -24 } },
        { kind = "jetpack", pos = { -110, 17, 30 }, respawn = 50, fuel = 3.5 },
        { kind = "jetpack", pos = { 110, 17, -30 }, respawn = 50, fuel = 3.5 },
    },

    -- S14 launch pads: port side bow -> island approach, starboard stern -> hangar mouth (visible arcs)
    LaunchPads = {
        { pos = { -100, 16.3, -40 }, target = { -30, 16.3, 34 }, apex = 22 },
        { pos = { 100, 16.3, 40 }, target = { 30, 16.3, -34 }, apex = 22 },
    },

    -- S6 flyovers: one every 30-60 s, low passes and formations mixed in
    Flyovers = { Interval = { 30, 60 }, Height = 90, Sound = "upload:JetPass" },

    -- S7 background fleet (non-playable, far outside the walls)
    Fleet = {
        { kind = "cruiser", pos = { -420, -22, -520 }, heading = 15 },
        { kind = "escort", pos = { 380, -22, -600 }, heading = -20 },
        { kind = "escort", pos = { 620, -22, 120 }, heading = 90 },
        { kind = "supply", pos = { -560, -22, 380 }, heading = 200 },
    },

    -- Signature events (S10 kraken is visual only in v1; jet launch is the hazard)
    Events = {
        {
            Name = "Jet Launch",
            TriggerPhase = 2,
            WarningSeconds = 8,
            DurationSeconds = 25,
            Banner = "JET LAUNCH  CLEAR THE CATAPULT",
            Sound = "upload:Siren",
            Flyover = true, -- a jet roars overhead as the sirens start
            Region = { pos = { -40, 22, -12 }, size = { 150, 14, 22 } },
            Shield = { pos = { 30, 16.5, -12 }, size = { 2, 0.5, 22 }, rise = 6 },
            Beacons = true,
        },
        {
            Name = "Kraken",
            Kind = "Kraken",
            TriggerPhase = 3,
            DurationSeconds = 14,
            Banner = "SOMETHING IN THE WATER",
            Sound = "upload:Kraken",
            Origin = { 40, -30, -230 }, -- port side, outside the walls
            Height = 130,
        },
    },

    Environment = {
        ClockTime = 17.4,
        Brightness = 2.0,
        Ambient = Color3.fromRGB(95, 105, 125),
        OutdoorAmbient = Color3.fromRGB(125, 135, 155),
        FogColor = Color3.fromRGB(165, 175, 195),
        FogStart = 220,
        FogEnd = 900,
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

    Palette = {
        Deck = Color3.fromRGB(58, 62, 70),
        DeckLine = Color3.fromRGB(235, 225, 190),
        DeckStrip = Color3.fromRGB(240, 215, 80),
        Hull = Color3.fromRGB(108, 116, 128),
        HullDark = Color3.fromRGB(70, 76, 88),
        Hangar = Color3.fromRGB(82, 88, 98),
        HangarZone = Color3.fromRGB(120, 110, 60),
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
        Mountains = { { 0, -60, -900, 260 }, { -500, -80, -850, 220 }, { 520, -70, -880, 240 } },
    },

    Center = {
        -- hull
        { kind = "block", name = "HullBottom", pos = { 0, -8, 0 }, size = { 300, 4, 90 }, color = "HullDark" },
        { kind = "block", name = "HullSideN", pos = { 0, 4, -46 }, size = { 300, 24, 2 }, color = "Hull" },
        { kind = "block", name = "HullSideS", pos = { 0, 4, 46 }, size = { 300, 24, 2 }, color = "Hull" },
        -- hangar: floor with painted zones, walls, suspended lights, scaffolding, workshop
        { kind = "block", name = "HangarFloor", pos = { 0, -1, 0 }, size = { 220, 2, 70 }, color = "Hangar" },
        { kind = "block", name = "HangarZoneMid", pos = { 0, 0.06, 0 }, size = { 40, 0.1, 40 }, color = "HangarZone" },
        { kind = "block", name = "HangarWallN", pos = { 0, 7, -34 }, size = { 220, 16, 2 }, color = "Hangar" },
        { kind = "block", name = "HangarWallS", pos = { 0, 7, 34 }, size = { 220, 16, 2 }, color = "Hangar" },
        { kind = "light", name = "HangarLight1", pos = { 0, 13, 0 }, color = "DeckLine", range = 60, brightness = 1.5 },
        { kind = "block", name = "LightRail", pos = { 0, 13.5, 0 }, size = { 200, 0.4, 0.4 }, color = "Steel" },
        { kind = "block", name = "Scaffold1", pos = { 30, 4, -28 }, size = { 12, 8, 4 }, color = "Hazard" },
        { kind = "block", name = "Scaffold1Deck", pos = { 30, 8.2, -28 }, size = { 12, 0.4, 4 }, color = "Steel" },
        { kind = "block", name = "Workbench", pos = { -30, 1.5, 26 }, size = { 10, 3, 3 }, color = "Steel" },
        { kind = "block", name = "ToolCart", pos = { -22, 1.5, 26 }, size = { 3, 3, 2 }, color = "Warning" },
        { kind = "block", name = "Crate1", pos = { 0, 2, -14 }, size = { 8, 4, 6 }, color = "Crate" },
        { kind = "block", name = "Crate2", pos = { 0, 2, 14 }, size = { 8, 4, 6 }, color = "Crate" },
        { kind = "jet", name = "HangarJetMid", pos = { 0, 0, 0 }, rot = { 0, 90, 0 } },
        { kind = "block", name = "MissileRack", pos = { -14, 1.5, -24 }, size = { 10, 3, 3 }, color = "Missile" },
        { kind = "block", name = "FuelHose", pos = { 14, 0.3, 24 }, size = { 16, 0.4, 0.4 }, color = "Warning" },
        { kind = "steam", name = "HangarVent1", pos = { 40, 0.5, -30 } },
        -- flight deck: markings, cables, tie-downs, lights, barriers
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
        {
            kind = "block",
            name = "LandingLine",
            pos = { 0, 16.06, 8 },
            size = { 3, 0.1, 30 },
            color = "DeckLine",
            rot = { 0, -12, 0 },
        },
        {
            kind = "block",
            name = "CatapultLine",
            pos = { -20, 16.06, -12 },
            size = { 120, 0.1, 0.6 },
            color = "DeckStrip",
        },
        { kind = "block", name = "Cable1", pos = { -10, 16.08, 8 }, size = { 0.3, 0.05, 30 }, color = "Steel" },
        { kind = "block", name = "Cable2", pos = { 0, 16.08, 8 }, size = { 0.3, 0.05, 30 }, color = "Steel" },
        { kind = "block", name = "Cable3", pos = { 10, 16.08, 8 }, size = { 0.3, 0.05, 30 }, color = "Steel" },
        { kind = "block", name = "TieDowns", pos = { 0, 16.04, -30 }, size = { 60, 0.05, 0.5 }, color = "HullDark" },
        {
            kind = "light",
            name = "DeckLightMid",
            pos = { 0, 22, -40 },
            color = "DeckLine",
            range = 50,
            brightness = 0.8,
        },
        { kind = "block", name = "Barrier1", pos = { 0, 17.2, -24 }, size = { 10, 2.4, 0.6 }, color = "Hazard" },
        { kind = "helicopter", name = "Helo", pos = { 22, 16, 26 }, rot = { 0, 40, 0 } },
        -- island: base, deck 2 (bridge), roof outpost A with rails and consoles, radar/antennas, beacon
        { kind = "block", name = "IslandBase", pos = { 0, 20, 42 }, size = { 30, 8, 14 }, color = "Island" },
        { kind = "block", name = "IslandDeck2", pos = { 0, 28, 42 }, size = { 26, 8, 12 }, color = "Island" },
        { kind = "block", name = "BridgeFloor", pos = { 0, 32.5, 42 }, size = { 26, 1, 12 }, color = "Deck" },
        { kind = "block", name = "BridgeConsole1", pos = { -6, 34.2, 42 }, size = { 2, 2.4, 6 }, color = "HullDark" },
        { kind = "block", name = "BridgeConsole2", pos = { 6, 34.2, 42 }, size = { 2, 2.4, 6 }, color = "HullDark" },
        { kind = "block", name = "BridgeWindows", pos = { 0, 35, 36.2 }, size = { 24, 2.5, 0.4 }, color = "HullDark" },
        { kind = "block", name = "IslandTop", pos = { 0, 36.5, 42 }, size = { 20, 1, 12 }, color = "Island" },
        { kind = "block", name = "IslandRailN", pos = { 0, 38, 36.5 }, size = { 20, 2, 0.4 }, color = "Hazard" },
        { kind = "block", name = "IslandRailS", pos = { 0, 38, 47.5 }, size = { 20, 2, 0.4 }, color = "Hazard" },
        { kind = "block", name = "RoofPlatform", pos = { 0, 36.9, 42 }, size = { 8, 0.2, 6 }, color = "DeckStrip" },
        { kind = "block", name = "Mast", pos = { 0, 50, 46 }, size = { 2, 26, 2 }, color = "Steel" },
        { kind = "radar", name = "RadarDish", pos = { 0, 63, 46 } },
        { kind = "block", name = "Antenna1", pos = { -6, 44, 46 }, size = { 0.4, 12, 0.4 }, color = "Steel" },
        { kind = "block", name = "Antenna2", pos = { 6, 46, 46 }, size = { 0.4, 16, 0.4 }, color = "Steel" },
        { kind = "block", name = "AntennaArray", pos = { 0, 42, 47.5 }, size = { 6, 3, 0.6 }, color = "HullDark" },
        { kind = "beacon", name = "MastBeacon", pos = { 0, 63.5, 46 }, color = "Warning" },
        {
            kind = "light",
            name = "BridgeLight",
            pos = { 0, 35.5, 42 },
            color = "DeckLine",
            range = 30,
            brightness = 1.2,
        },
        { kind = "steam", name = "IslandVent", pos = { -14, 24.2, 42 } },
        -- jet blast deflector at the catapult end (the event raises it)
        { kind = "block", name = "BlastShield", pos = { 30, 16.5, -12 }, size = { 2, 0.5, 22 }, color = "Hazard" },
    },

    Mirrored = {
        -- deck ends with an elevator cutout on the port side, numbers, extra markings
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
        { kind = "block", name = "BowNumber", pos = { -135, 16.06, 0 }, size = { 12, 0.1, 8 }, color = "DeckLine" },
        { kind = "block", name = "EdgeLineN", pos = { -110, 16.06, -43 }, size = { 80, 0.1, 0.6 }, color = "DeckLine" },
        { kind = "block", name = "EdgeLineS", pos = { -110, 16.06, 43 }, size = { 80, 0.1, 0.6 }, color = "DeckLine" },
        {
            kind = "light",
            name = "DeckLightEnd",
            pos = { -110, 22, 40 },
            color = "DeckLine",
            range = 50,
            brightness = 0.8,
        },
        -- big props: jets, tractor, fuel + maintenance carts, crates, wing section cover
        { kind = "jet", name = "DeckJet1", pos = { -88, 16, -28 }, rot = { 0, 20, 0 } },
        { kind = "jet", name = "DeckJet2", pos = { -68, 16, 24 }, rot = { 0, -30, 0 } },
        { kind = "jet", name = "DeckJet3", pos = { -118, 16, 26 }, rot = { 0, 10, 0 } },
        { kind = "block", name = "Tractor", pos = { -35, 17.5, 30 }, size = { 5, 3, 4 }, color = "Hazard" },
        { kind = "block", name = "FuelCart", pos = { -25, 17.5, -30 }, size = { 6, 3, 4 }, color = "Warning" },
        { kind = "block", name = "MaintCart", pos = { -95, 17.3, 8 }, size = { 3, 2.6, 2 }, color = "Steel" },
        { kind = "block", name = "DeckCrates", pos = { -100, 17.5, -8 }, size = { 6, 3, 10 }, color = "Crate" },
        {
            kind = "block",
            name = "WingSection",
            pos = { -45, 17.2, 8 },
            size = { 10, 0.6, 6 },
            color = "Jet",
            rot = { 0, 0, 20 },
        },
        {
            kind = "block",
            name = "Barrier2",
            pos = { -70, 17.2, -2 },
            size = { 8, 2.4, 0.6 },
            color = "Hazard",
            rot = { 0, 30, 0 },
        },
        -- catwalks both edges + stairs; stern catwalk overlook = sniper outpost B (mirrored bow twin is a decoy platform)
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
        { kind = "block", name = "CatwalkSupport", pos = { -80, 6, -47 }, size = { 1, 12, 1 }, color = "Steel" },
        { kind = "block", name = "Overlook", pos = { -128, 23.5, -44 }, size = { 12, 1, 8 }, color = "Steel" },
        { kind = "block", name = "OverlookRail", pos = { -128, 25, -47.8 }, size = { 12, 2, 0.4 }, color = "Hazard" },
        {
            kind = "block",
            name = "OverlookStair",
            pos = { -120, 20, -44 },
            size = { 10, 0.5, 5 },
            color = "Steel",
            rot = { 0, 0, -35 },
        },
        -- hangar end: ramp down from the deck end, door frame, corridor with alcoves
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
        { kind = "block", name = "HangarCrate1", pos = { -60, 2, -8 }, size = { 8, 4, 8 }, color = "Crate" },
        { kind = "block", name = "HangarCrate2", pos = { -40, 2, 10 }, size = { 8, 4, 8 }, color = "Crate" },
        { kind = "block", name = "AircraftParts", pos = { -75, 1.2, -20 }, size = { 8, 2.4, 3 }, color = "Jet" },
        { kind = "jet", name = "HangarJet", pos = { -85, 0, 12 }, rot = { 0, 100, 0 } },
        { kind = "block", name = "CorridorWall", pos = { -60, 5, 28 }, size = { 80, 12, 1 }, color = "HullDark" },
        { kind = "block", name = "CorridorDoor1", pos = { -95, 4, 28 }, size = { 6, 9, 1.2 }, color = "Hazard" },
        { kind = "block", name = "CorridorDoor2", pos = { -25, 4, 28 }, size = { 6, 9, 1.2 }, color = "Hazard" },
        { kind = "block", name = "Alcove", pos = { -50, 4, 31 }, size = { 6, 8, 1 }, color = "HullDark" },
        { kind = "steam", name = "CorridorVent", pos = { -70, 0.5, 30 } },
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
        {
            kind = "block",
            name = "RoofLadder",
            pos = { -11, 34.5, 42 },
            size = { 1, 5, 3 },
            color = "Hazard",
            rot = { 0, 0, -70 },
        },
        -- lane markers toward the deck objective
        { kind = "marker", pos = { -60, 16, -12 }, size = { 40, 0.3, 1.5 } },
    },
}
