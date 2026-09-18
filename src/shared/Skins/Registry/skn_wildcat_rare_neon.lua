-- Rare: shiny gold + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_wildcat_rare_neon",
    Weapon = "Wildcat",
    Tier = "Rare",
    Concept = "The Wildcat goes neon: shiny gold, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "polished gold", Accent = "glow accents" },
    SoundPalette = "arcade synth",
    Systems = {
        Texture = {
            Body = { Color = { 235, 190, 60 }, Material = "Metal", Reflectance = 0.55 },
            Overrides = {
                Barrel = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Muzzle = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Bolt = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Magazine = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Scope = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Core = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Emitter = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Barrels = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
                Edge = { Color = { 80, 255, 120 }, Material = "Neon", Reflectance = 0.55 },
            },
        },
        FireSound = { Fire = "rbxassetid://4812801977", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
