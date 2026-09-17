-- Builds Rivals-stat weapons from Roblox's Weapons Kit models.
-- Run: lune run tools/build_weapons.luau
-- Reads assets/weapons/*.rbxm (raw downloads), writes:
--   assets/WeaponsSystem.rbxm          the kit's system folder (once)
--   assets/weapons/tools/<Name>.rbxm   one Tool per Rivals weapon
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Weapons = require("../src/shared/Weapons")

-- Rivals weapon -> kit model to start from
local BASE = {
    AssaultRifle = "AutoRifle",
    BurstRifle = "AutoRifle",
    Wildcat = "SubmachineGun",
    Uzi = "SubmachineGun",
    Minigun = "SubmachineGun",
    Shotgun = "Shotgun",
    Shorty = "Shotgun",
    Sniper = "SniperRifle",
    Handgun = "Pistol",
    Revolver = "Pistol",
    Spray = "Pistol",
}

local function firstTool(file)
    local roots = roblox.deserializeModel(fs.readFile("assets/weapons/" .. file .. ".rbxm"))
    for _, r in roots do
        if r:IsA("Tool") then
            return r
        end
    end
    error("no Tool in " .. file)
end

local function setValue(config, name, class, value)
    local existing = config:FindFirstChild(name)
    if existing and existing.ClassName ~= class then
        existing:Destroy()
        existing = nil
    end
    if not existing then
        existing = Instance.new(class)
        existing.Name = name
        existing.Parent = config
    end
    existing.Value = value
end

-- Rivals damage goes near -> far over a range; the kit goes full -> zero.
-- Extend the kit's zero point so the slope matches Rivals over its range.
local function zeroDistance(stats)
    local near, far = stats.Damage[1], stats.Damage[2]
    if stats.DropoffStart == math.huge or near == far then
        return 100000
    end
    local slope = (near - far) / (stats.DropoffEnd - stats.DropoffStart)
    return stats.DropoffStart + near / slope
end

local function applyStats(tool, name, stats)
    local config = tool:FindFirstChild("Configuration")
    assert(config, "no Configuration in " .. tool.Name)
    setValue(config, "HitDamage", "NumberValue", stats.Damage[1])
    setValue(config, "NumProjectiles", "IntValue", stats.Pellets)
    setValue(config, "ShotCooldown", "NumberValue", stats.Cooldown)
    setValue(config, "AmmoCapacity", "IntValue", stats.Ammo[1] == math.huge and 999 or stats.Ammo[1])
    local reload = stats.EmptyReload or stats.Reload
    if stats.SegmentedReload then
        reload = stats.Reload * stats.Ammo[1] -- kit reloads the whole mag at once
    end
    setValue(config, "ReloadTime", "NumberValue", reload)
    setValue(config, "StartupTime", "NumberValue", stats.EquipTime)
    setValue(config, "MinSpread", "NumberValue", stats.Spread * 0.5)
    setValue(config, "MaxSpread", "NumberValue", stats.Spread)
    setValue(config, "FullDamageDistance", "NumberValue", stats.DropoffStart == math.huge and 100000 or stats.DropoffStart)
    setValue(config, "ZeroDamageDistance", "NumberValue", zeroDistance(stats))
    setValue(config, "BulletSpeed", "NumberValue", 20000) -- effectively hitscan, like Rivals
    setValue(config, "GravityFactor", "NumberValue", 0)
    setValue(config, "MaxDistance", "NumberValue", 2000)
    if stats.Burst then
        setValue(config, "FireMode", "StringValue", "Burst")
        setValue(config, "NumBurstShots", "IntValue", stats.Burst)
        setValue(config, "BurstShotCooldown", "NumberValue", stats.BurstDelay)
    else
        setValue(config, "FireMode", "StringValue", stats.Auto and "Automatic" or "Semiautomatic")
    end
    setValue(config, "HasScope", "BoolValue", name == "Sniper")
    -- Crit multiplier read by our damage callback for headshots
    setValue(config, "CritMultiplier", "NumberValue", stats.Crit[1] / stats.Damage[1])
end

-- 1. System folder, taken once from the Pistol download
do
    local roots = roblox.deserializeModel(fs.readFile("assets/weapons/Pistol.rbxm"))
    local system
    for _, r in roots do
        system = r:FindFirstChild("WeaponsSystem")
        if system then
            break
        end
    end
    assert(system, "WeaponsSystem folder not found")
    system.Parent = nil
    -- Patch: pass hit info and the weapon to the damage callback so we can do headshot crits.
    local bullet = system.WeaponTypes.BulletWeapon
    local src = bullet.Source
    local before = "self.weaponsSystem.doDamage(hitInfo.h, damage, nil, self.player)"
    local after = "self.weaponsSystem.doDamage(hitInfo.h, damage, nil, self.player, hitInfo, self.instance)"
    assert(src:find(before, 1, true), "BulletWeapon doDamage call not found; kit changed?")
    bullet.Source = src:gsub(before:gsub("%p", "%%%0"), after)
    fs.writeFile("assets/WeaponsSystem.rbxm", roblox.serializeModel({ system }))
    print("wrote assets/WeaponsSystem.rbxm")
end

-- 2. One clean Tool per Rivals weapon
fs.writeDir("assets/weapons/tools")
local count = 0
for name, base in BASE do
    local stats = Weapons[name]
    assert(stats, "no stats for " .. name)
    local tool = firstTool(base)
    tool.Name = name
    local embedded = tool:FindFirstChild("WeaponsSystem")
    if embedded then
        embedded:Destroy()
    end
    applyStats(tool, name, stats)
    fs.writeFile("assets/weapons/tools/" .. name .. ".rbxm", roblox.serializeModel({ tool }))
    count += 1
end
print("wrote " .. count .. " tools to assets/weapons/tools/")
