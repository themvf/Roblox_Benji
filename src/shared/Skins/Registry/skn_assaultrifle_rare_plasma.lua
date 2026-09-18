-- Rare: shiny gold + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_assaultrifle_rare_plasma",
    Weapon = "AssaultRifle",
    Tier = "Rare",
    Concept = "The AssaultRifle goes plasma: shiny gold, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "polished gold", Accent = "glow accents" },
    SoundPalette = "energy hum",
    Systems = {
        Texture = {
            Body = { Color = { 235, 190, 60 }, Material = "Metal", Reflectance = 0.55 },
            Overrides = {
                Barrel = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Muzzle = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Bolt = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Magazine = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Scope = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Core = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Emitter = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Barrels = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
                Edge = { Color = { 120, 255, 200 }, Material = "Neon", Reflectance = 0.55 },
            },
        },
        FireSound = { Fire = "rbxassetid://4812801977", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
