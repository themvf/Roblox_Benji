-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_minigun_rare_storm",
    Weapon = "Minigun",
    Tier = "Rare",
    Concept = "The Minigun goes storm: a storm body, a new voice, and a railgun trail on every shot",
    Materials = { Primary = "storm finish", Accent = "glow accents" },
    SoundPalette = "thunder",
    Systems = {
        Texture = {
            Body = { Color = { 60, 65, 80 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 120, 200, 255 }, Material = "Neon" },
                Muzzle = { Color = { 120, 200, 255 }, Material = "Neon" },
                Bolt = { Color = { 120, 200, 255 }, Material = "Neon" },
                Magazine = { Color = { 120, 200, 255 }, Material = "Neon" },
                Scope = { Color = { 120, 200, 255 }, Material = "Neon" },
                Core = { Color = { 120, 200, 255 }, Material = "Neon" },
                Emitter = { Color = { 120, 200, 255 }, Material = "Neon" },
                Barrels = { Color = { 120, 200, 255 }, Material = "Neon" },
                Edge = { Color = { 120, 200, 255 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3821795742", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Railgun" },
    },
}
