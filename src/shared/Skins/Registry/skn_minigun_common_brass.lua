-- Common: flat recolour. Works today on the kit mesh.
return {
    Id = "skn_minigun_common_brass",
    Weapon = "Minigun",
    Tier = "Common",
    Concept = "The Minigun in brass: same gun, brass body with a contrasting business end",
    Materials = { Primary = "brass metal", Accent = "accent metal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 200, 160, 80 }, Material = "Metal" },
            Overrides = {
                Barrel = { Color = { 90, 70, 40 }, Material = "Metal" },
                Muzzle = { Color = { 90, 70, 40 }, Material = "Metal" },
                Bolt = { Color = { 90, 70, 40 }, Material = "Metal" },
                Magazine = { Color = { 90, 70, 40 }, Material = "Metal" },
                Scope = { Color = { 90, 70, 40 }, Material = "Metal" },
                Core = { Color = { 90, 70, 40 }, Material = "Metal" },
                Emitter = { Color = { 90, 70, 40 }, Material = "Metal" },
                Barrels = { Color = { 90, 70, 40 }, Material = "Metal" },
                Edge = { Color = { 90, 70, 40 }, Material = "Metal" },
            },
        },
    },
}
