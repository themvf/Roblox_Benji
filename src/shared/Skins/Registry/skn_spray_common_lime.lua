-- Common: texture only. Generated recolour; works today on the kit mesh.
return {
    Id = "skn_spray_common_lime",
    Weapon = "Spray",
    Tier = "Common",
    Concept = "The Spray in lime: same gun, lime body with a contrasting business end",
    Materials = { Primary = "lime smoothplastic", Accent = "accent metal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 140, 220, 70 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 40, 60, 40 }, Material = "Metal" },
                Muzzle = { Color = { 40, 60, 40 }, Material = "Metal" },
                Bolt = { Color = { 40, 60, 40 }, Material = "Metal" },
                Magazine = { Color = { 40, 60, 40 }, Material = "Metal" },
                Scope = { Color = { 40, 60, 40 }, Material = "Metal" },
                Core = { Color = { 40, 60, 40 }, Material = "Metal" },
                Emitter = { Color = { 40, 60, 40 }, Material = "Metal" },
                Barrels = { Color = { 40, 60, 40 }, Material = "Metal" },
                Edge = { Color = { 40, 60, 40 }, Material = "Metal" },
            },
        },
    },
}
