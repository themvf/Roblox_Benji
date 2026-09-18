-- Common: texture only. Generated recolour; works today on the kit mesh.
return {
    Id = "skn_energypistols_common_mint",
    Weapon = "EnergyPistols",
    Tier = "Common",
    Concept = "The EnergyPistols in mint: same gun, mint body with a contrasting business end",
    Materials = { Primary = "mint smoothplastic", Accent = "accent neon" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 200, 255, 230 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 60, 200, 160 }, Material = "Neon" },
                Muzzle = { Color = { 60, 200, 160 }, Material = "Neon" },
                Bolt = { Color = { 60, 200, 160 }, Material = "Neon" },
                Magazine = { Color = { 60, 200, 160 }, Material = "Neon" },
                Scope = { Color = { 60, 200, 160 }, Material = "Neon" },
                Core = { Color = { 60, 200, 160 }, Material = "Neon" },
                Emitter = { Color = { 60, 200, 160 }, Material = "Neon" },
                Barrels = { Color = { 60, 200, 160 }, Material = "Neon" },
                Edge = { Color = { 60, 200, 160 }, Material = "Neon" },
            },
        },
    },
}
