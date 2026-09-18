-- Common: texture only. Generated recolour; works today on the kit mesh.
return {
    Id = "skn_energyrifle_common_pearl",
    Weapon = "EnergyRifle",
    Tier = "Common",
    Concept = "The EnergyRifle in pearl: same gun, pearl body with a contrasting business end",
    Materials = { Primary = "pearl smoothplastic", Accent = "accent neon" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 245, 245, 250 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 200, 90 }, Material = "Neon" },
                Muzzle = { Color = { 255, 200, 90 }, Material = "Neon" },
                Bolt = { Color = { 255, 200, 90 }, Material = "Neon" },
                Magazine = { Color = { 255, 200, 90 }, Material = "Neon" },
                Scope = { Color = { 255, 200, 90 }, Material = "Neon" },
                Core = { Color = { 255, 200, 90 }, Material = "Neon" },
                Emitter = { Color = { 255, 200, 90 }, Material = "Neon" },
                Barrels = { Color = { 255, 200, 90 }, Material = "Neon" },
                Edge = { Color = { 255, 200, 90 }, Material = "Neon" },
            },
        },
    },
}
