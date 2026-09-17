-- Weapon stats. The client reads these for fire rate and ammo; the server
-- re-reads them so a hacked client cannot change damage.
local Weapons = {}

Weapons.Shotgun = {
    Damage = 12,
    Pellets = 8,
    Spread = 6,
    FireRate = 0.9,
    MagSize = 6,
    ReloadTime = 2.2,
    Range = 60,
}
Weapons.AssaultRifle = {
    Damage = 18,
    Pellets = 1,
    Spread = 1.5,
    FireRate = 0.1,
    MagSize = 30,
    ReloadTime = 1.8,
    Range = 300,
}
Weapons.Sniper = {
    Damage = 90,
    Pellets = 1,
    Spread = 0,
    FireRate = 1.2,
    MagSize = 5,
    ReloadTime = 2.5,
    Range = 1000,
    HeadshotMultiplier = 2,
}

return Weapons
