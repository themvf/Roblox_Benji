-- Common: texture only. Generated recolour; works today on the kit mesh.
return {
    Id = "skn_uzi_common_cobalt",
    Weapon = "Uzi",
    Tier = "Common",
    Concept = "The Uzi in cobalt: same gun, cobalt body with a contrasting business end",
    Materials = { Primary = "cobalt smoothplastic", Accent = "accent metal" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            Body = { Color = { 40, 70, 200 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 230, 190, 90 }, Material = "Metal" },
                Muzzle = { Color = { 230, 190, 90 }, Material = "Metal" },
                Bolt = { Color = { 230, 190, 90 }, Material = "Metal" },
                Magazine = { Color = { 230, 190, 90 }, Material = "Metal" },
                Scope = { Color = { 230, 190, 90 }, Material = "Metal" },
                Core = { Color = { 230, 190, 90 }, Material = "Metal" },
                Emitter = { Color = { 230, 190, 90 }, Material = "Metal" },
                Barrels = { Color = { 230, 190, 90 }, Material = "Metal" },
                Edge = { Color = { 230, 190, 90 }, Material = "Metal" },
            },
        },
    },
}
