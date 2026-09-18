-- Common: flat recolour. Works today on the kit mesh.
return {
    Id = "skn_revolver_common_ivory",
    Weapon = "Revolver",
    Tier = "Common",
    Concept = "The Revolver in ivory: same gun, ivory body with a contrasting business end",
    Materials = { Primary = "ivory smoothplastic", Accent = "accent wood" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 240, 232, 215 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 140, 90, 50 }, Material = "Wood" },
                Muzzle = { Color = { 140, 90, 50 }, Material = "Wood" },
                Bolt = { Color = { 140, 90, 50 }, Material = "Wood" },
                Magazine = { Color = { 140, 90, 50 }, Material = "Wood" },
                Scope = { Color = { 140, 90, 50 }, Material = "Wood" },
                Core = { Color = { 140, 90, 50 }, Material = "Wood" },
                Emitter = { Color = { 140, 90, 50 }, Material = "Wood" },
                Barrels = { Color = { 140, 90, 50 }, Material = "Wood" },
                Edge = { Color = { 140, 90, 50 }, Material = "Wood" },
            },
        },
    },
}
