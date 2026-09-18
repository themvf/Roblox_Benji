-- Common: texture only. Generated recolour; works today on the kit mesh.
return {
    Id = "skn_sniper_common_arctic",
    Weapon = "Sniper",
    Tier = "Common",
    Concept = "The Sniper in arctic: same gun, arctic body with a contrasting business end",
    Materials = { Primary = "arctic smoothplastic", Accent = "accent neon" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 230, 235, 245 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 90, 150, 255 }, Material = "Neon" },
                Muzzle = { Color = { 90, 150, 255 }, Material = "Neon" },
                Bolt = { Color = { 90, 150, 255 }, Material = "Neon" },
                Magazine = { Color = { 90, 150, 255 }, Material = "Neon" },
                Scope = { Color = { 90, 150, 255 }, Material = "Neon" },
                Core = { Color = { 90, 150, 255 }, Material = "Neon" },
                Emitter = { Color = { 90, 150, 255 }, Material = "Neon" },
                Barrels = { Color = { 90, 150, 255 }, Material = "Neon" },
                Edge = { Color = { 90, 150, 255 }, Material = "Neon" },
            },
        },
    },
}
