-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_shotgun_rare_magma",
    Weapon = "Shotgun",
    Tier = "Rare",
    Concept = "The Shotgun goes magma: a magma body, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "magma finish", Accent = "glow accents" },
    SoundPalette = "volcanic rumble",
    Systems = {
        Texture = {
            Body = { Color = { 50, 25, 25 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 90, 30 }, Material = "Neon" },
                Muzzle = { Color = { 255, 90, 30 }, Material = "Neon" },
                Bolt = { Color = { 255, 90, 30 }, Material = "Neon" },
                Magazine = { Color = { 255, 90, 30 }, Material = "Neon" },
                Scope = { Color = { 255, 90, 30 }, Material = "Neon" },
                Core = { Color = { 255, 90, 30 }, Material = "Neon" },
                Emitter = { Color = { 255, 90, 30 }, Material = "Neon" },
                Barrels = { Color = { 255, 90, 30 }, Material = "Neon" },
                Edge = { Color = { 255, 90, 30 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3821795742", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
