-- Rare: shiny gold + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_shotgun_rare_magma",
    Weapon = "Shotgun",
    Tier = "Rare",
    Concept = "The Shotgun goes magma: shiny gold, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "polished gold", Accent = "glow accents" },
    SoundPalette = "volcanic rumble",
    Systems = {
        Texture = {
            Body = { Color = { 235, 190, 60 }, Material = "Metal", Reflectance = 0.55 },
            Overrides = {
                Barrel = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Muzzle = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Bolt = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Magazine = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Scope = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Core = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Emitter = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Barrels = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
                Edge = { Color = { 255, 90, 30 }, Material = "Neon", Reflectance = 0.55 },
            },
        },
        FireSound = { Fire = "rbxassetid://3821795742", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
