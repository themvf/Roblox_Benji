-- Rare: shiny gold + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_shorty_rare_frost",
    Weapon = "Shorty",
    Tier = "Rare",
    Concept = "The Shorty goes frost: shiny gold, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "polished gold", Accent = "glow accents" },
    SoundPalette = "ice crack",
    Systems = {
        Texture = {
            Body = { Color = { 235, 190, 60 }, Material = "Metal", Reflectance = 0.55 },
            Overrides = {
                Barrel = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Muzzle = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Bolt = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Magazine = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Scope = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Core = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Emitter = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Barrels = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
                Edge = { Color = { 120, 200, 255 }, Material = "Neon", Reflectance = 0.55 },
            },
        },
        FireSound = { Fire = "rbxassetid://3821795742", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
