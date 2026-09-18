-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_spray_rare_toxic",
    Weapon = "Spray",
    Tier = "Rare",
    Concept = "The Spray goes toxic: a toxic body, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "toxic finish", Accent = "glow accents" },
    SoundPalette = "bubbling",
    Systems = {
        Texture = {
            Body = { Color = { 40, 60, 40 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 150, 255, 60 }, Material = "Neon" },
                Muzzle = { Color = { 150, 255, 60 }, Material = "Neon" },
                Bolt = { Color = { 150, 255, 60 }, Material = "Neon" },
                Magazine = { Color = { 150, 255, 60 }, Material = "Neon" },
                Scope = { Color = { 150, 255, 60 }, Material = "Neon" },
                Core = { Color = { 150, 255, 60 }, Material = "Neon" },
                Emitter = { Color = { 150, 255, 60 }, Material = "Neon" },
                Barrels = { Color = { 150, 255, 60 }, Material = "Neon" },
                Edge = { Color = { 150, 255, 60 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://4812801977", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
