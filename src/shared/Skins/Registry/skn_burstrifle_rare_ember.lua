-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_burstrifle_rare_ember",
    Weapon = "BurstRifle",
    Tier = "Rare",
    Concept = "The BurstRifle goes ember: a ember body, a new voice, and a railgun trail on every shot",
    Materials = { Primary = "ember finish", Accent = "glow accents" },
    SoundPalette = "crackling fire",
    Systems = {
        Texture = {
            Body = { Color = { 60, 30, 30 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 120, 40 }, Material = "Neon" },
                Muzzle = { Color = { 255, 120, 40 }, Material = "Neon" },
                Bolt = { Color = { 255, 120, 40 }, Material = "Neon" },
                Magazine = { Color = { 255, 120, 40 }, Material = "Neon" },
                Scope = { Color = { 255, 120, 40 }, Material = "Neon" },
                Core = { Color = { 255, 120, 40 }, Material = "Neon" },
                Emitter = { Color = { 255, 120, 40 }, Material = "Neon" },
                Barrels = { Color = { 255, 120, 40 }, Material = "Neon" },
                Edge = { Color = { 255, 120, 40 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3821792787", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Railgun" },
    },
}
