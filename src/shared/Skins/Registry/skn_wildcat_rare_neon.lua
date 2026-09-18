-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_wildcat_rare_neon",
    Weapon = "Wildcat",
    Tier = "Rare",
    Concept = "The Wildcat goes neon: a neon body, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "neon finish", Accent = "glow accents" },
    SoundPalette = "arcade synth",
    Systems = {
        Texture = {
            Body = { Color = { 25, 25, 35 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 80, 255, 120 }, Material = "Neon" },
                Muzzle = { Color = { 80, 255, 120 }, Material = "Neon" },
                Bolt = { Color = { 80, 255, 120 }, Material = "Neon" },
                Magazine = { Color = { 80, 255, 120 }, Material = "Neon" },
                Scope = { Color = { 80, 255, 120 }, Material = "Neon" },
                Core = { Color = { 80, 255, 120 }, Material = "Neon" },
                Emitter = { Color = { 80, 255, 120 }, Material = "Neon" },
                Barrels = { Color = { 80, 255, 120 }, Material = "Neon" },
                Edge = { Color = { 80, 255, 120 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://4812801977", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
