-- Rare demo that works today: recolor + the sniper's boom for a fire sound + the kit's Railgun tracer.
-- Proves the full apply path (Texture, FireSound, ProjectileTracer) without any new art.
return {
    Id = "skn_handgun_rare_thunder",
    Weapon = "Handgun",
    Tier = "Rare",
    Concept = "The handgun is a thunder pistol: every shot cracks like a rifle and leaves a lightning trail",
    Materials = { Primary = "storm-grey steel", Accent = "electric blue" },
    SoundPalette = "thunder foley",
    Systems = {
        Texture = {
            Body = { Color = { 70, 75, 90 }, Material = "Metal" },
            Overrides = {
                Barrel = { Color = { 90, 200, 255 }, Material = "Neon" },
                Bolt = { Color = { 90, 200, 255 }, Material = "Neon" },
            },
        },
        FireSound = { Fire = "rbxassetid://3821795742", DryFire = "TODO", Impact = "TODO" },
        ProjectileTracer = { ShotEffect = "Railgun" },
    },
}
