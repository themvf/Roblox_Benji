-- Mythical worked example from the spec: every system replaced, one idea throughout.
return {
    Id = "skn_uzi_myth_keyzi",
    Weapon = "Uzi",
    Tier = "Mythical",
    Concept = "The Uzi is a key, the Keyzi: it fires teeth and reloads by turning in a lock",
    Materials = { Primary = "brass key", Accent = "iron lock" },
    SoundPalette = "lock and key foley",
    Systems = {
        Model = { Asset = "TODO", SilhouetteDeviation = 0.12 },
        Texture = { Asset = "TODO" },
        FireSound = { Fire = "TODO", DryFire = "TODO", Impact = "TODO" },
        EquipReloadSound = { Equip = "TODO", ReloadStages = { "TODO" }, Chamber = "TODO" },
        ReloadAnimation = { FirstPerson = "TODO", ThirdPerson = "TODO" },
        FireEquipAnimation = { Fire = "TODO", Equip = "TODO", Idle = "TODO", Sprint = "TODO" },
        ProjectileTracer = { Projectile = "TODO", Tracer = "TODO", Trail = "TODO" },
        Effects = { Muzzle = "TODO", Impact = "TODO", HitConfirm = "TODO", Kill = "TODO", Ambient = "TODO" },
        Inspect = { Animation = "TODO", EasterEgg = "TODO" },
    },
}
