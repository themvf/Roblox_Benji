-- Builds Rivals-stat weapons from Roblox's Weapons Kit models.
-- Run: lune run tools/build_weapons.luau
-- Reads assets/weapons/*.rbxm (raw downloads), writes:
--   assets/WeaponsSystem.rbxm          the kit's system folder (once)
--   assets/weapons/tools/<Name>.rbxm   one Tool per Rivals weapon
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Enum = roblox.Enum
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Vector2 = roblox.Vector2
local NumberRange = roblox.NumberRange
local NumberSequence = roblox.NumberSequence
local ColorSequence = roblox.ColorSequence
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
    setValue(
        config,
        "FullDamageDistance",
        "NumberValue",
        stats.DropoffStart == math.huge and 100000 or stats.DropoffStart
    )
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

-- 2a. Melee tools built from parts (no kit involvement; MeleeService drives them)
fs.writeDir("assets/weapons/tools")
local function part(name, size, color, material, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.CanCollide = false
    p.Massless = true
    if shape then
        p.Shape = shape
    end
    return p
end

local function weld(a, b, c0)
    local w = Instance.new("Weld")
    w.Part0 = a
    w.Part1 = b
    w.C0 = c0
    w.Parent = a
end

local function buildKatana()
    local tool = Instance.new("Tool")
    tool.Name = "Katana"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ManualActivationOnly = true
    tool.Grip = CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.rad(0))
    tool:SetAttribute("WeaponClass", "Melee")

    local handle = part("Handle", Vector3.new(0.3, 1.3, 0.3), Color3.fromRGB(40, 40, 48), Enum.Material.Fabric)
    handle.Parent = tool
    local guard = part("Guard", Vector3.new(0.9, 0.15, 0.6), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
    guard.Parent = tool
    weld(handle, guard, CFrame.new(0, 0.75, 0))
    local blade = part("Blade", Vector3.new(0.12, 4.2, 0.55), Color3.fromRGB(235, 240, 250), Enum.Material.Metal)
    blade.Parent = tool
    weld(handle, blade, CFrame.new(0, 2.95, 0) * CFrame.Angles(0, 0, math.rad(2)))
    local edge = part("Edge", Vector3.new(0.05, 4.1, 0.12), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
    edge.Parent = tool
    weld(handle, edge, CFrame.new(0, 2.95, -0.28) * CFrame.Angles(0, 0, math.rad(2)))
    local pommel = part("Pommel", Vector3.new(0.35, 0.2, 0.35), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
    pommel.Parent = tool
    weld(handle, pommel, CFrame.new(0, -0.7, 0))

    -- Preview model for the kiosk viewport (same parts, grouped)
    local model = Instance.new("Model")
    model.Name = "Katana"
    for _, p in { handle, guard, blade, edge, pommel } do
        p:Clone().Parent = model
    end
    model.PrimaryPart = model:FindFirstChild("Handle")
    model.Parent = tool
    return tool
end

fs.writeFile("assets/weapons/tools/Katana.rbxm", roblox.serializeModel({ buildKatana() }))
print("wrote assets/weapons/tools/Katana.rbxm")

local function buildJetpack()
    local tool = Instance.new("Tool")
    tool.Name = "Jetpack"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ManualActivationOnly = true
    tool.Grip = CFrame.new(0, -0.2, 0)
    tool:SetAttribute("WeaponClass", "Utility")

    -- in-hand remote
    local handle = part("Handle", Vector3.new(0.4, 0.9, 0.25), Color3.fromRGB(40, 40, 48), Enum.Material.SmoothPlastic)
    handle.Parent = tool
    local button = part("Button", Vector3.new(0.2, 0.2, 0.1), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
    button.Parent = tool
    weld(handle, button, CFrame.new(0, 0.2, -0.15))

    -- pack worn on the back (server welds it to the torso when equipped)
    local pack = Instance.new("Model")
    pack.Name = "Pack"
    local body = part("Body", Vector3.new(1.6, 1.8, 0.7), Color3.fromRGB(230, 230, 235), Enum.Material.Metal)
    body.Anchored = true
    body.Parent = pack
    pack.PrimaryPart = body
    for i, x in { -0.5, 0.5 } do
        local tank = part(
            "Tank" .. i,
            Vector3.new(0.55, 1.9, 0.55),
            Color3.fromRGB(255, 120, 40),
            Enum.Material.SmoothPlastic,
            Enum.PartType.Cylinder
        )
        tank.Anchored = true
        tank.CFrame = body.CFrame * CFrame.new(x, 0, 0.1) * CFrame.Angles(0, 0, math.rad(90))
        tank.Parent = pack
        weld(body, tank, CFrame.new(x, 0, 0.1) * CFrame.Angles(0, 0, math.rad(90)))
        local nozzle = part(
            "Nozzle" .. i,
            Vector3.new(0.35, 0.35, 0.35),
            Color3.fromRGB(60, 60, 70),
            Enum.Material.Metal,
            Enum.PartType.Cylinder
        )
        nozzle.Anchored = true
        nozzle.CFrame = body.CFrame * CFrame.new(x, -1.15, 0.1) * CFrame.Angles(0, 0, math.rad(90))
        nozzle.Parent = pack
        weld(body, nozzle, CFrame.new(x, -1.15, 0.1) * CFrame.Angles(0, 0, math.rad(90)))
        local att = Instance.new("Attachment")
        att.Name = "Flame"
        att.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
        att.Parent = nozzle
        local flame = Instance.new("ParticleEmitter")
        flame.Name = "FlameFx"
        flame.Enabled = false
        flame.Rate = 60
        flame.Lifetime = NumberRange.new(0.25, 0.45)
        flame.Speed = NumberRange.new(18, 26)
        flame.SpreadAngle = Vector2.new(8, 8)
        flame.Size = NumberSequence.new(0.5, 0.1)
        flame.Transparency = NumberSequence.new(0.1, 1)
        flame.LightEmission = 1
        flame.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 30))
        flame.Parent = att
    end
    pack.Parent = tool

    -- kiosk preview model
    local preview = pack:Clone()
    preview.Name = "Jetpack"
    preview.Parent = tool
    return tool
end

fs.writeFile("assets/weapons/tools/Jetpack.rbxm", roblox.serializeModel({ buildJetpack() }))
print("wrote assets/weapons/tools/Jetpack.rbxm")

-- 2b. One clean Tool per Rivals gun, from the kit models
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
