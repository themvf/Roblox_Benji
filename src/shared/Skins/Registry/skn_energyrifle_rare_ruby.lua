-- Rare: shiny gold + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_energyrifle_rare_ruby",
    Weapon = "EnergyRifle",
    Tier = "Rare",
    Concept = "The EnergyRifle goes ruby: shiny gold, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "polished gold", Accent = "glow accents" },
    SoundPalette = "crystal chime",
    Systems = {
        Texture = {
            Body = { Color = { 235, 190, 60 }, Material = "Metal", Reflectance = 0.55 },
            Overrides = {
                Barrel = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Muzzle = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Bolt = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Magazine = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Scope = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Core = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Emitter = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Barrels = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
                Edge = { Color = { 255, 80, 110 }, Material = "Neon", Reflectance = 0.55 },
            },
        },
        FireSound = { Fire = "rbxassetid://3806349898", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
