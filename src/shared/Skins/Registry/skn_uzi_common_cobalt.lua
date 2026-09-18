-- Common: texture only. Works today with the Weapons Kit (recolors the base mesh).
return {
    Id = "skn_uzi_common_cobalt",
    Weapon = "Uzi",
    Tier = "Common",
    Concept = "The Uzi is dipped in cobalt: same gun, deep blue body with a brass business end",
    Materials = { Primary = "cobalt enamel", Accent = "brass" },
    SoundPalette = "base",
    Systems = {
        Texture = {
            -- Applied to every BasePart of the weapon model unless overridden by name
            Body = { Color = { 40, 70, 200 }, Material = "SmoothPlastic" },
            -- Business end stays the highest contrast part
            Overrides = {
                Barrel = { Color = { 230, 190, 90 }, Material = "Metal" },
                Muzzle = { Color = { 230, 190, 90 }, Material = "Metal" },
            },
        },
    },
}
