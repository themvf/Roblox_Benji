-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_energyrifle_rare_ruby",
    Weapon = "EnergyRifle",
    Tier = "Rare",
    Concept = "The EnergyRifle goes ruby: a ruby body, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "ruby finish", Accent = "glow accents" },
    SoundPalette = "crystal chime",
    Systems = {
        Texture = {
            Body = { Color = { 120, 20, 40 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 80, 110 }, Material = "Neon" },
                Muzzle = { Color = { 255, 80, 110 }, Material = "Neon" },
                Bolt = { Color = { 255, 80, 110 }, Material = "Neon" },
                Magazine = { Color = { 255, 80, 110 }, Material = "Neon" },
                Scope = { Color = { 255, 80, 110 }, Material = "Neon" },
                Core = { Color = { 255, 80, 110 }, Material = "Neon" },
                Emitter = { Color = { 255, 80, 110 }, Material = "Neon" },
                Barrels = { Color = { 255, 80, 110 }, Material = "Neon" },
                Edge = { Color = { 255, 80, 110 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3806349898", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
