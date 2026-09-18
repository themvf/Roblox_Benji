-- Common: texture only. Generated recolour; works today on the kit mesh.
return {
    Id = "skn_assaultrifle_common_crimson",
    Weapon = "AssaultRifle",
    Tier = "Common",
    Concept = "The AssaultRifle in crimson: same gun, crimson body with a contrasting business end",
    Materials = { Primary = "crimson smoothplastic", Accent = "accent metal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 190, 40, 50 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 240, 200, 90 }, Material = "Metal" },
                Muzzle = { Color = { 240, 200, 90 }, Material = "Metal" },
                Bolt = { Color = { 240, 200, 90 }, Material = "Metal" },
                Magazine = { Color = { 240, 200, 90 }, Material = "Metal" },
                Scope = { Color = { 240, 200, 90 }, Material = "Metal" },
                Core = { Color = { 240, 200, 90 }, Material = "Metal" },
                Emitter = { Color = { 240, 200, 90 }, Material = "Metal" },
                Barrels = { Color = { 240, 200, 90 }, Material = "Metal" },
                Edge = { Color = { 240, 200, 90 }, Material = "Metal" },
            },
        },
    },
}
