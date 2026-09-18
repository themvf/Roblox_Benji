-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_revolver_rare_outlaw",
    Weapon = "Revolver",
    Tier = "Rare",
    Concept = "The Revolver goes outlaw: a outlaw body, a new voice, and a railgun trail on every shot",
    Materials = { Primary = "outlaw finish", Accent = "glow accents" },
    SoundPalette = "western twang",
    Systems = {
        Texture = {
            Body = { Color = { 40, 35, 35 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 170, 50 }, Material = "Neon" },
                Muzzle = { Color = { 255, 170, 50 }, Material = "Neon" },
                Bolt = { Color = { 255, 170, 50 }, Material = "Neon" },
                Magazine = { Color = { 255, 170, 50 }, Material = "Neon" },
                Scope = { Color = { 255, 170, 50 }, Material = "Neon" },
                Core = { Color = { 255, 170, 50 }, Material = "Neon" },
                Emitter = { Color = { 255, 170, 50 }, Material = "Neon" },
                Barrels = { Color = { 255, 170, 50 }, Material = "Neon" },
                Edge = { Color = { 255, 170, 50 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3821792787", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Railgun" },
    },
}
