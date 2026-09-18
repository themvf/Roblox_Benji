-- Common: flat recolour. Works today on the kit mesh.
return {
    Id = "skn_wildcat_common_sunset",
    Weapon = "Wildcat",
    Tier = "Common",
    Concept = "The Wildcat in sunset: same gun, sunset body with a contrasting business end",
    Materials = { Primary = "sunset smoothplastic", Accent = "accent neon" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 255, 150, 60 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 230, 120 }, Material = "Neon" },
                Muzzle = { Color = { 255, 230, 120 }, Material = "Neon" },
                Bolt = { Color = { 255, 230, 120 }, Material = "Neon" },
                Magazine = { Color = { 255, 230, 120 }, Material = "Neon" },
                Scope = { Color = { 255, 230, 120 }, Material = "Neon" },
                Core = { Color = { 255, 230, 120 }, Material = "Neon" },
                Emitter = { Color = { 255, 230, 120 }, Material = "Neon" },
                Barrels = { Color = { 255, 230, 120 }, Material = "Neon" },
                Edge = { Color = { 255, 230, 120 }, Material = "Neon" },
            },
        },
    },
}
