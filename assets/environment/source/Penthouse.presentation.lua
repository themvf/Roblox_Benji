-- Presentation for Penthouse: the top of a tower at dusk. Sea = true with a very low
-- level means there is no ground field round the map; fog hides the drop. The rooms are
-- under a roof, so ambient is kept high enough to read faces between the ceiling lights.
return {
    Terrain = {
        GroundMaterial = Enum.Material.Water,
        Sea = true,
        SeaLevel = -430,
    },
    Palette = {
        Floor = Color3.fromRGB(214, 210, 202),
        Wall = Color3.fromRGB(232, 228, 220),
        Cover = Color3.fromRGB(62, 66, 76),
    },
    Vista = { pos = { -150, 70, -170 }, look = { 0, 6, -10 }, seconds = 3 },
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
        ClockTime = 18.2,
        Brightness = 1.6,
        Ambient = Color3.fromRGB(112, 114, 128),
        OutdoorAmbient = Color3.fromRGB(120, 116, 132),
        FogStart = 260,
        FogEnd = 1400,
        FogColor = Color3.fromRGB(72, 70, 96),
        Atmosphere = { Density = 0.22, Haze = 1.2, Glare = 0.1, Color = Color3.fromRGB(190, 160, 170) },
        SunRays = 0.05,
        Bloom = 0.2,
        Saturation = 0.08,
        Contrast = 0.1,
        Tint = Color3.fromRGB(255, 250, 244),
    },
}
