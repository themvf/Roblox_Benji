-- Common: flat recolour. Works today on the kit mesh.
return {
    Id = "skn_shorty_common_cherry",
    Weapon = "Shorty",
    Tier = "Common",
    Concept = "The Shorty in cherry: same gun, cherry body with a contrasting business end",
    Materials = { Primary = "cherry smoothplastic", Accent = "accent wood" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 170, 40, 60 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 60, 40, 40 }, Material = "Wood" },
                Muzzle = { Color = { 60, 40, 40 }, Material = "Wood" },
                Bolt = { Color = { 60, 40, 40 }, Material = "Wood" },
                Magazine = { Color = { 60, 40, 40 }, Material = "Wood" },
                Scope = { Color = { 60, 40, 40 }, Material = "Wood" },
                Core = { Color = { 60, 40, 40 }, Material = "Wood" },
                Emitter = { Color = { 60, 40, 40 }, Material = "Wood" },
                Barrels = { Color = { 60, 40, 40 }, Material = "Wood" },
                Edge = { Color = { 60, 40, 40 }, Material = "Wood" },
            },
        },
    },
}
