-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_assaultrifle_rare_plasma",
    Weapon = "AssaultRifle",
    Tier = "Rare",
    Concept = "The AssaultRifle goes plasma: a plasma body, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "plasma finish", Accent = "glow accents" },
    SoundPalette = "energy hum",
    Systems = {
        Texture = {
            Body = { Color = { 30, 40, 60 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 120, 255, 200 }, Material = "Neon" },
                Muzzle = { Color = { 120, 255, 200 }, Material = "Neon" },
                Bolt = { Color = { 120, 255, 200 }, Material = "Neon" },
                Magazine = { Color = { 120, 255, 200 }, Material = "Neon" },
                Scope = { Color = { 120, 255, 200 }, Material = "Neon" },
                Core = { Color = { 120, 255, 200 }, Material = "Neon" },
                Emitter = { Color = { 120, 255, 200 }, Material = "Neon" },
                Barrels = { Color = { 120, 255, 200 }, Material = "Neon" },
                Edge = { Color = { 120, 255, 200 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://4812801977", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
