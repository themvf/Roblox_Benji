-- Common: texture only. Generated recolour; works today on the kit mesh.
return {
    Id = "skn_burstrifle_common_olive",
    Weapon = "BurstRifle",
    Tier = "Common",
    Concept = "The BurstRifle in olive: same gun, olive body with a contrasting business end",
    Materials = { Primary = "olive smoothplastic", Accent = "accent metal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 95, 120, 60 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 230, 220, 190 }, Material = "Metal" },
                Muzzle = { Color = { 230, 220, 190 }, Material = "Metal" },
                Bolt = { Color = { 230, 220, 190 }, Material = "Metal" },
                Magazine = { Color = { 230, 220, 190 }, Material = "Metal" },
                Scope = { Color = { 230, 220, 190 }, Material = "Metal" },
                Core = { Color = { 230, 220, 190 }, Material = "Metal" },
                Emitter = { Color = { 230, 220, 190 }, Material = "Metal" },
                Barrels = { Color = { 230, 220, 190 }, Material = "Metal" },
                Edge = { Color = { 230, 220, 190 }, Material = "Metal" },
            },
        },
    },
}
