-- Weapon stats copied from the Rivals wiki (robloxrivals.fandom.com), Update 22.
-- Damage and Crit are {near, far}: full damage inside DropoffStart studs,
-- scaling linearly to the far value at DropoffEnd studs.
-- Cooldown is seconds between shots. Auto = hold to fire; otherwise click per shot.
-- Ammo is {magazine, reserve}; reserve = math.huge for infinite.
-- Energy weapons are approximated as hitscan (no wall bounce yet).
local Weapons = {}

-- ===== Primary =====
Weapons.AssaultRifle = {
    Slot = "Primary",
    Damage = { 12, 3 },
    Crit = { 15, 4 },
    DropoffStart = 50,
    DropoffEnd = 200,
    Cooldown = 0.10,
    Spread = 1.0,
    Pellets = 1,
    Ammo = { 20, 100 },
    Reload = 1.56,
    EquipTime = 0.65,
    MoveSpeed = -0.10,
    Auto = true,
}

Weapons.BurstRifle = {
    Slot = "Primary",
    Damage = { 20, 5 },
    Crit = { 25, 6 },
    DropoffStart = 60,
    DropoffEnd = 200,
    Cooldown = 0.60,
    Spread = 2.0,
    Pellets = 1,
    Burst = 3,
    BurstDelay = 0.08,
    Ammo = { 12, 60 },
    Reload = 1.60,
    EquipTime = 0.75,
    MoveSpeed = -0.10,
    Auto = false,
}

Weapons.Shotgun = {
    Slot = "Primary",
    Damage = { 8, 2.5 },
    Crit = { 12, 3.7 },
    DropoffStart = 10,
    DropoffEnd = 50,
    Cooldown = 0.70,
    Spread = 6.5,
    Pellets = 10,
    Ammo = { 7, 35 },
    Reload = 0.55, -- segmented: one shell at a time
    SegmentedReload = true,
    EquipTime = 0.75,
    MoveSpeed = 0,
    Auto = false,
}

Weapons.Sniper = {
    Slot = "Primary",
    Damage = { 50, 50 },
    Crit = { 150, 150 },
    DropoffStart = math.huge,
    DropoffEnd = math.huge,
    Cooldown = 1.50,
    Spread = 15.0, -- hip fire; ADS spread is 0
    AimSpread = 0,
    Pellets = 1,
    Ammo = { 4, 12 },
    Reload = 1.80,
    EmptyReload = 2.13,
    EquipTime = 1.15,
    MoveSpeed = -0.20,
    Auto = false,
}

Weapons.Wildcat = {
    Slot = "Primary",
    Damage = { 9, 2.2 },
    Crit = { 11.25, 2.75 },
    DropoffStart = 30,
    DropoffEnd = 90,
    Cooldown = 0.06,
    Spread = 3.0,
    Pellets = 1,
    Ammo = { 24, 96 },
    Reload = 1.0,
    EmptyReload = 2.0,
    EquipTime = 0.45,
    MoveSpeed = 0,
    Auto = true,
}

Weapons.Minigun = {
    Slot = "Primary",
    Damage = { 8, 4 },
    Crit = { 10, 5 },
    DropoffStart = 50,
    DropoffEnd = 200,
    Cooldown = 0.05,
    Spread = 2.0,
    AimSpread = 1.0,
    Pellets = 1,
    Ammo = { 300, 0 },
    Reload = 0,
    Windup = 0.80,
    EquipTime = 1.00,
    MoveSpeed = -0.25,
    Auto = true,
}

Weapons.EnergyRifle = {
    Slot = "Primary",
    Damage = { 20, 20 },
    Crit = { 25, 25 },
    DropoffStart = math.huge,
    DropoffEnd = math.huge,
    Cooldown = 0.30,
    Spread = 0,
    Pellets = 1,
    Ammo = { math.huge, math.huge },
    Reload = 0,
    EquipTime = 1.05,
    MoveSpeed = 0,
    Auto = true,
}

-- ===== Secondary =====
Weapons.Handgun = {
    Slot = "Secondary",
    Damage = { 12, 3 },
    Crit = { 15, 4 },
    DropoffStart = 50,
    DropoffEnd = 125,
    Cooldown = 0.13,
    Spread = 0.5,
    Pellets = 1,
    Ammo = { 13, 91 },
    Reload = 1.06,
    EquipTime = 0.20,
    MoveSpeed = 0,
    Auto = false,
}

Weapons.Revolver = {
    Slot = "Secondary",
    Damage = { 30, 8 },
    Crit = { 40, 10 },
    DropoffStart = 75,
    DropoffEnd = 200,
    Cooldown = 0.40,
    Spread = 0.5,
    Pellets = 1,
    Ammo = { 6, 36 },
    Reload = 1.80,
    EmptyReload = 1.16,
    FanCooldown = 0.15, -- right-click ability: fire remaining shots at this rate
    EquipTime = 0.60,
    MoveSpeed = -0.05,
    Auto = false,
}

Weapons.Shorty = {
    Slot = "Secondary",
    Damage = { 7.5, 2.5 },
    Crit = { 11.2, 3.7 },
    DropoffStart = 10,
    DropoffEnd = 25,
    Cooldown = 0.12,
    Spread = 6.5,
    AimSpread = 4.9,
    Pellets = 10,
    Ammo = { 2, 18 },
    Reload = 1.70,
    EquipTime = 0.60,
    MoveSpeed = 0,
    Auto = false,
}

Weapons.Spray = {
    Slot = "Secondary",
    Damage = { 8, 2 },
    Crit = { 10, 2 },
    DropoffStart = 50,
    DropoffEnd = 125,
    Cooldown = 0.50,
    Spread = 0.5,
    Pellets = 1,
    Burst = 5,
    BurstDelay = 0.04,
    Ammo = { 30, 90 },
    Reload = 1.30,
    EmptyReload = 1.50,
    EquipTime = 0.45,
    MoveSpeed = 0.05,
    Auto = false,
}

Weapons.Uzi = {
    Slot = "Secondary",
    Damage = { 8, 2 },
    Crit = { 10, 2 },
    DropoffStart = 50,
    DropoffEnd = 125,
    Cooldown = 0.07,
    Spread = 1.0,
    AimSpread = 1.0,
    Pellets = 1,
    Ammo = { 27, 108 },
    Reload = 1.50,
    EquipTime = 0.45,
    MoveSpeed = 0,
    Auto = true,
}

Weapons.EnergyPistols = {
    Slot = "Secondary",
    Damage = { 2.1, 2.1 },
    Crit = { 2.625, 2.625 },
    DropoffStart = math.huge,
    DropoffEnd = math.huge,
    Cooldown = 0.03,
    Spread = 0,
    Pellets = 1,
    Ammo = { math.huge, math.huge },
    Reload = 0,
    EquipTime = 0.60,
    MoveSpeed = 0,
    Auto = true,
}

-- Damage for one pellet at a given distance, with headshot crit.
function Weapons.DamageAt(stats, distance, headshot)
    local near, far = table.unpack(headshot and stats.Crit or stats.Damage)
    if distance <= stats.DropoffStart then
        return near
    end
    if distance >= stats.DropoffEnd then
        return far
    end
    local t = (distance - stats.DropoffStart) / (stats.DropoffEnd - stats.DropoffStart)
    return near + (far - near) * t
end

return Weapons
