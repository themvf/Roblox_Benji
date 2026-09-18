-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_uzi_rare_laser",
    Weapon = "Uzi",
    Tier = "Rare",
    Concept = "The Uzi goes laser: a laser body, a new voice, and a plasma trail on every shot",
    Materials = { Primary = "laser finish", Accent = "glow accents" },
    SoundPalette = "laser pew",
    Systems = {
        Texture = {
            Body = { Color = { 30, 30, 40 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 60, 60 }, Material = "Neon" },
                Muzzle = { Color = { 255, 60, 60 }, Material = "Neon" },
                Bolt = { Color = { 255, 60, 60 }, Material = "Neon" },
                Magazine = { Color = { 255, 60, 60 }, Material = "Neon" },
                Scope = { Color = { 255, 60, 60 }, Material = "Neon" },
                Core = { Color = { 255, 60, 60 }, Material = "Neon" },
                Emitter = { Color = { 255, 60, 60 }, Material = "Neon" },
                Barrels = { Color = { 255, 60, 60 }, Material = "Neon" },
                Edge = { Color = { 255, 60, 60 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3806566911", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Plasma" },
    },
}
