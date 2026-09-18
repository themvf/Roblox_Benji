-- Rare: shiny gold + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_spray_rare_toxic",
    Weapon = "Spray",
    Tier = "Rare",
    Concept = "The Spray goes toxic: shiny gold, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "polished gold", Accent = "glow accents" },
    SoundPalette = "bubbling",
    Systems = {
        Texture = {
            Body = { Color = { 235, 190, 60 }, Material = "Metal", Reflectance = 0.55 },
            Overrides = {
                Barrel = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Muzzle = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Bolt = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Magazine = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Scope = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Core = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Emitter = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Barrels = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
                Edge = { Color = { 150, 255, 60 }, Material = "Neon", Reflectance = 0.55 },
            },
        },
        FireSound = { Fire = "rbxassetid://4812801977", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
