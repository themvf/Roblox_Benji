-- Presentation for this map: sky, lighting, terrain and palette. Optional to edit.
--
-- This file is yours. The converter created it once with defaults and never
-- overwrites it; your edits are merged into the generated map every conversion.
-- Spatial things -- objectives, spawns, bounds -- are NOT set here. They come
-- only from the markers in the .rbxm, so there is one place to move them.
--
-- Allowed keys: Palette, Terrain, Environment, Vista, Seed.
-- Vista (the intro camera) is generated from the boundary unless you set one:
--     Vista = { pos = { -225, 80, -190 }, look = { 0, 8, 0 }, seconds = 3 },
return {
    Terrain = {
        -- The terrain field under and around the map. Its top is at y = 0.
        GroundMaterial = Enum.Material.Snow,
        GroundColor = Color3.fromRGB(226, 233, 240),
    },
    Palette = {
        Floor = Color3.fromRGB(180, 184, 190),
        Wall = Color3.fromRGB(102, 110, 122),
        Cover = Color3.fromRGB(122, 130, 140),
    },
    Environment = {
        -- Remove Sky to keep whatever sky the place already has.
        Sky = {
            Ft = "rbxassetid://2029211409",
            Bk = "rbxassetid://2029210131",
            Lf = "rbxassetid://2029212393",
            Rt = "rbxassetid://2029212849",
            Up = "rbxassetid://2029213271",
            Dn = "rbxassetid://2029210773",
            CelestialBodiesShown = true,
        },
        ClockTime = 12,
        Brightness = 2,
        Ambient = Color3.fromRGB(160, 160, 160),
        OutdoorAmbient = Color3.fromRGB(170, 170, 170),
        FogStart = 900,
        FogEnd = 3000,
        FogColor = Color3.fromRGB(190, 195, 205),
        Atmosphere = { Density = 0, Haze = 0, Glare = 0, Color = Color3.fromRGB(255, 255, 255) },
        SunRays = 0,
        Bloom = 0,
        Saturation = 0,
        Contrast = 0,
        Tint = Color3.fromRGB(255, 255, 255),
    },
}
