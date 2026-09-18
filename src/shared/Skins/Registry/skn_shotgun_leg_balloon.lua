-- Legendary worked example from the spec. Asset ids are placeholders until art delivers;
-- the validator checks structure and tier, not whether the assets exist yet.
return {
    Id = "skn_shotgun_leg_balloon",
    Weapon = "Shotgun",
    Tier = "Legendary",
    Concept = "The shotgun is a bundle of balloons: shells pop and reloads are taped on",
    Materials = { Primary = "latex balloon", Accent = "adhesive tape" },
    SoundPalette = "party foley",
    Systems = {
        Model = { Asset = "TODO", SilhouetteDeviation = 0.10 },
        FireSound = { Fire = "TODO", DryFire = "TODO", Impact = "TODO" },
        EquipReloadSound = { Equip = "TODO", ReloadStages = { "TODO" }, Chamber = "TODO" },
        ReloadAnimation = { FirstPerson = "TODO", ThirdPerson = "TODO" },
        Effects = { Muzzle = "TODO", Impact = "TODO", HitConfirm = "TODO", Kill = "TODO" },
    },
}
