-- Rare: recolour + new fire sound + tracer. Sound and effect are kit assets, so it works today.
return {
    Id = "skn_handgun_rare_gold",
    Weapon = "Handgun",
    Tier = "Rare",
    Concept = "The Handgun goes gold: a gold body, a new voice, and a railgun trail on every shot",
    Materials = { Primary = "gold finish", Accent = "glow accents" },
    SoundPalette = "cash register",
    Systems = {
        Texture = {
            Body = { Color = { 230, 190, 70 }, Material = "SmoothPlastic" },
            Overrides = {
                Barrel = { Color = { 255, 240, 200 }, Material = "Neon" },
                Muzzle = { Color = { 255, 240, 200 }, Material = "Neon" },
                Bolt = { Color = { 255, 240, 200 }, Material = "Neon" },
                Magazine = { Color = { 255, 240, 200 }, Material = "Neon" },
                Scope = { Color = { 255, 240, 200 }, Material = "Neon" },
                Core = { Color = { 255, 240, 200 }, Material = "Neon" },
                Emitter = { Color = { 255, 240, 200 }, Material = "Neon" },
                Barrels = { Color = { 255, 240, 200 }, Material = "Neon" },
                Edge = { Color = { 255, 240, 200 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3821795742", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Railgun" },
    },
}
