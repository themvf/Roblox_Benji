-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_energypistols_rare_solar",
    Weapon = "EnergyPistols",
    Tier = "Rare",
    Concept = "The EnergyPistols goes solar: a solar body, a new voice, and a railgun trail on every shot",
    Materials = { Primary = "solar finish", Accent = "glow accents" },
    SoundPalette = "sun flare",
    Systems = {
        Texture = {
            Body = { Color = { 255, 210, 80 }, Material = "SmoothPlastic" },
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
        FireSound = { Fire = "rbxassetid://3806349898", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Railgun" },
    },
}
