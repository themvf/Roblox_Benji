-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_shorty_rare_frost",
    Weapon = "Shorty",
    Tier = "Rare",
    Concept = "The Shorty goes frost: a frost body, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "frost finish", Accent = "glow accents" },
    SoundPalette = "ice crack",
    Systems = {
        Texture = {
            Body = { Color = { 200, 230, 255 }, Material = "SmoothPlastic" },
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
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
