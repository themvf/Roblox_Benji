-- Common: flat recolour. Works today on the kit mesh.
return {
    Id = "skn_shotgun_common_teal",
    Weapon = "Shotgun",
    Tier = "Common",
    Concept = "The Shotgun in teal: same gun, teal body with a contrasting business end",
    Materials = { Primary = "teal smoothplastic", Accent = "accent metal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 40, 140, 140 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 240, 240, 240 }, Material = "Metal" },
                Muzzle = { Color = { 240, 240, 240 }, Material = "Metal" },
                Bolt = { Color = { 240, 240, 240 }, Material = "Metal" },
                Magazine = { Color = { 240, 240, 240 }, Material = "Metal" },
                Scope = { Color = { 240, 240, 240 }, Material = "Metal" },
                Core = { Color = { 240, 240, 240 }, Material = "Metal" },
                Emitter = { Color = { 240, 240, 240 }, Material = "Metal" },
                Barrels = { Color = { 240, 240, 240 }, Material = "Metal" },
                Edge = { Color = { 240, 240, 240 }, Material = "Metal" },
            },
        },
    },
}
