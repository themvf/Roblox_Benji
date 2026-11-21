-- Presentation for SciFiFoundry: gritty enclosed industrial foundry lighting & palette.
-- Lower ambient + Atmosphere haze lets focused worklights & Shadows carve contrast instead
-- of flat floodlit plastic. Sea=-40 keeps Roblox smooth Terrain below the sealed arena.
return {
    Terrain = {
        GroundMaterial = Enum.Material.Water,
        Sea = true,
        SeaLevel = -40,
    },
    Palette = {
        Floor = Color3.fromRGB(48, 54, 64),
        Wall = Color3.fromRGB(40, 46, 56),
        Cover = Color3.fromRGB(96, 106, 120),
    },
    Vista = { pos = { -68, 22, -96 }, look = { 0, 8, -4 }, seconds = 2.5 },
    Environment = {
        Sky = {
            Ft = "rbxassetid://2029211409",
            Bk = "rbxassetid://2029210131",
            Lf = "rbxassetid://2029212393",
            Rt = "rbxassetid://2029212849",
            Up = "rbxassetid://2029213271",
            Dn = "rbxassetid://2029210773",
            CelestialBodiesShown = true,
        },
        ClockTime = 14.0,
        Brightness = 2.15,
        Ambient = Color3.fromRGB(108, 120, 138),
        OutdoorAmbient = Color3.fromRGB(118, 130, 148),
        EnvironmentDiffuseScale = 1.0,
        EnvironmentSpecularScale = 1.0,
        ShadowSoftness = 0.22,
        FogStart = 220,
        FogEnd = 1100,
        FogColor = Color3.fromRGB(54, 64, 78),
        Atmosphere = {
            Density = 0.14,
            Haze = 0.95,
            Glare = 0.10,
            Color = Color3.fromRGB(132, 152, 178),
        },
        SunRays = 0,
        Bloom = 0.14,
        Saturation = 0.14,
        Contrast = 0.16,
        Tint = Color3.fromRGB(255, 255, 255),
    },
}
