-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_sniper_rare_void",
    Weapon = "Sniper",
    Tier = "Rare",
    Concept = "The Sniper goes void: a void body, a new voice, and a railgun trail on every shot",
    Materials = { Primary = "void finish", Accent = "glow accents" },
    SoundPalette = "deep space",
    Systems = {
        Texture = {
            Body = { Color = { 20, 18, 30 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 170, 80, 255 }, Material = "Neon" },
                Muzzle = { Color = { 170, 80, 255 }, Material = "Neon" },
                Bolt = { Color = { 170, 80, 255 }, Material = "Neon" },
                Magazine = { Color = { 170, 80, 255 }, Material = "Neon" },
                Scope = { Color = { 170, 80, 255 }, Material = "Neon" },
                Core = { Color = { 170, 80, 255 }, Material = "Neon" },
                Emitter = { Color = { 170, 80, 255 }, Material = "Neon" },
                Barrels = { Color = { 170, 80, 255 }, Material = "Neon" },
                Edge = { Color = { 170, 80, 255 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3821792787", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Railgun" },
    },
}
