-- Common: flat recolour. Works today on the kit mesh.
return {
    Id = "skn_handgun_common_slate",
    Weapon = "Handgun",
    Tier = "Common",
    Concept = "The Handgun in slate: same gun, slate body with a contrasting business end",
    Materials = { Primary = "slate metal", Accent = "accent metal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 80, 85, 95 }, Material = "Metal" },
            Overrides = {
                Barrel = { Color = { 200, 200, 205 }, Material = "Metal" },
                Muzzle = { Color = { 200, 200, 205 }, Material = "Metal" },
                Bolt = { Color = { 200, 200, 205 }, Material = "Metal" },
                Magazine = { Color = { 200, 200, 205 }, Material = "Metal" },
                Scope = { Color = { 200, 200, 205 }, Material = "Metal" },
                Core = { Color = { 200, 200, 205 }, Material = "Metal" },
                Emitter = { Color = { 200, 200, 205 }, Material = "Metal" },
                Barrels = { Color = { 200, 200, 205 }, Material = "Metal" },
                Edge = { Color = { 200, 200, 205 }, Material = "Metal" },
            },
        },
    },
}
