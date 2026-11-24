-- Builds Rivals-stat weapons from Roblox's Weapons Kit models.
-- Run: lune run tools/build_weapons.luau
-- Reads assets/weapons/*.rbxm (raw downloads), writes:
--   assets/WeaponsSystem.rbxm          the kit's system folder (once)
--   assets/weapons/tools/<Name>.rbxm   one Tool per Rivals weapon
local fs = require("@lune/fs")
local serde = require("@lune/serde")
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
    HeavyCannon = "SubmachineGun",
    PlasmaBlaster = "AutoRifle",
    Halcyon = "AutoRifle",
    PrismBlaster = "AutoRifle",
    LightningCarbine = "AutoRifle",
    PulseRifle = "SniperRifle",
    Shotgun = "Shotgun",
    Frostbite = "Shotgun",
    Shorty = "Shotgun",
    Sniper = "SniperRifle",
    WhiteSniper = "SniperRifle",
    Handgun = "Pistol",
    Revolver = "Pistol",
    Spray = "Pistol",
    RayGun = "Pistol",
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
    setValue(config, "HasScope", "BoolValue", name == "Sniper" or name == "WhiteSniper" or name == "PulseRifle")
    if stats.DamageFractionOfMaxHealth then
        setValue(config, "DamageFractionOfMaxHealth", "NumberValue", stats.DamageFractionOfMaxHealth)
    end
    -- Crit multiplier read by our damage callback for headshots
    setValue(config, "CritMultiplier", "NumberValue", stats.Crit[1] / stats.Damage[1])
end

local function attachWhiteSniperArt(tool)
    local manifest = serde.decode("json", fs.readFile("assets/models/white-sniper/studio_import.json"))
    assert(#manifest.parts == 8, "White Sniper Studio import must have eight mesh sections")
    local model = tool:FindFirstChild("Sniper")
    local rifle = model and model:FindFirstChild("Rifle")
    assert(rifle and model.PrimaryPart == rifle, "Sniper kit Rifle and firing attachments must remain intact")

    -- The kit model still supplies the muzzle, bolt, and grip used by its scripts.
    -- Hide only its geometry, then weld the uploaded visual to the same rifle.
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Transparency = 1
        end
    end
    local alignment = rifle.CFrame * CFrame.Angles(0, math.pi, 0)
    for _, record in manifest.parts do
        local mesh = Instance.new("MeshPart")
        mesh.Name = record.name
        mesh.MeshId = record.meshId
        mesh.Size = Vector3.new(unpack(record.size))
        mesh.CFrame = alignment * CFrame.new(unpack(record.offset))
        mesh.Color = Color3.new(1, 1, 1)
        mesh.Anchored = false
        mesh.CanCollide = false
        mesh.CanTouch = false
        mesh.CanQuery = false
        mesh.Massless = true
        local surface = Instance.new("SurfaceAppearance")
        surface.ColorMap = record.colorMap
        surface.MetalnessMap = record.metalnessMap
        surface.RoughnessMap = record.roughnessMap
        if record.normalMap ~= "" then
            surface.NormalMap = record.normalMap
        end
        surface.Parent = mesh
        mesh.Parent = model
        local joint = Instance.new("WeldConstraint")
        joint.Name = "ArtWeld"
        joint.Part0 = rifle
        joint.Part1 = mesh
        joint.Parent = mesh
    end
end

-- Guns uploaded through tools/asset_generate.py: weapon name -> registry entry.
-- The registry holds the Grip and Muzzle mounts (studs from the pivot, -Z forward);
-- assets/models/<package>/studio_import.json holds the uploaded mesh and texture ids.
local REGISTRY_ART = {
    Frostbite = "frostbite",
    HeavyCannon = "heavy-cannon",
    PlasmaBlaster = "plasma-blaster",
    Halcyon = "halcyon-rifle",
    PrismBlaster = "prism-blaster",
    PulseRifle = "pulse-rifle",
    RayGun = "ray-gun",
}

-- Guns whose muzzle is a glowing window: a texture cannot emit light, so a thin Neon plate
-- sits inside the window (studs from the art's pivot, -Z forward) with a GlowLight, and the
-- tool is tagged GlowPart so WeaponGlowController flares it on every shot.
local MUZZLE_GLOW = {
    PulseRifle = {
        -- Window face at z -2.12, frame ring forward to about -2.23; the opening is
        -- 0.22 x 0.27 studs, so the plate's edges tuck under the ring.
        centre = Vector3.new(0, 0.165, -2.15),
        size = Vector3.new(0.24, 0.28, 0.02),
        color = Color3.fromRGB(176, 96, 255),
    },
}

-- Uploaded parts that glow: weapon name -> part name -> Neon colour. The part is made Neon
-- (its palette texture dropped, since Neon draws one flat colour), gets a GlowLight, and the
-- tool is tagged GlowPart so WeaponGlowController flares it on every shot.
local GLOW_PARTS = {
    PlasmaBlaster = { Core = Color3.fromRGB(255, 120, 24) },
    -- The barrel strip and front lens (cyan), and the strip's rear end (magenta).
    Halcyon = { GlowCyan = Color3.fromRGB(90, 225, 255), GlowMagenta = Color3.fromRGB(240, 70, 220) },
    -- The crystal's core and the light behind it in the window.
    PrismBlaster = { Glow = Color3.fromRGB(176, 128, 255) },
    -- The lightning bolt between the copper coil rails.
    LightningCarbine = { Arc = Color3.fromRGB(140, 215, 255) },
}

-- Uploaded parts drawn as Glass over a glow: weapon name -> part name -> Transparency. The
-- part keeps its palette texture (facets painted light, mid and dark) so the cut still reads.
local GLASS_PARTS = {
    PrismBlaster = { Crystal = 0.3 },
}
local GLOW_LIGHT_RANGE = 4 -- resting values; Tuning WeaponGlow_* overrides them in play
local GLOW_LIGHT_BRIGHTNESS = 1.5

-- A registry gun with a Core mount gets a glowing core: one textured mesh cannot glow
-- in part, so a Neon disc runs across the body there and shows on both faces.
local CORE_DIAMETER = 0.34
local CORE_COLOR = Color3.fromRGB(255, 200, 40)

local function addCoreGlow(model, mesh, alignment, core)
    local disc = Instance.new("Part")
    disc.Name = "CoreGlow"
    disc.Shape = Enum.PartType.Cylinder -- cylinder axis is X, across the gun
    disc.Size = Vector3.new(mesh.Size.X + 0.04, CORE_DIAMETER, CORE_DIAMETER)
    disc.Material = Enum.Material.Neon
    disc.Color = CORE_COLOR
    disc.CFrame = alignment * CFrame.new(core)
    disc.Anchored = false
    disc.CanCollide = false
    disc.CanTouch = false
    disc.CanQuery = false
    disc.Massless = true
    disc.CastShadow = false
    disc.Parent = model
    local light = Instance.new("PointLight")
    light.Color = CORE_COLOR
    light.Range = 4
    light.Brightness = 1.5
    light.Parent = disc
    local joint = Instance.new("WeldConstraint")
    joint.Name = "ArtWeld"
    joint.Part0 = mesh
    joint.Part1 = disc
    joint.Parent = disc
end

local function v3(t)
    return Vector3.new(t[1], t[2], t[3])
end

local function attachRegistryArt(tool, name)
    local entry = serde.decode("json", fs.readFile("src/shared/AssetRegistry.json"))[REGISTRY_ART[name]]
    assert(entry and entry.kind == "weapon" and entry.assetId, name .. ": no uploaded weapon in AssetRegistry.json")
    local manifest = serde.decode("json", fs.readFile(entry.package .. "/studio_import.json"))
    assert(manifest.assetId == entry.assetId, name .. ": studio_import.json is for another upload")

    local model = tool:FindFirstChildWhichIsA("Model")
    local body = model and model.PrimaryPart
    local handle = body and body:FindFirstChild("HandleAttachment")
    local tip = body and body:FindFirstChild("TipAttachment")
    assert(handle and tip, name .. ": kit model needs HandleAttachment and TipAttachment")

    -- Kit barrels point along +Z, registry art along -Z: turn half a turn, then put
    -- the art's Grip where the kit's hand goes.
    local turn = CFrame.Angles(0, math.pi, 0)
    local grip = turn * v3(entry.mounts.Grip)
    local offset = handle.CFrame.Position - grip
    local alignment = body.CFrame * CFrame.new(offset) * turn

    -- Shots and flashes leave from the art's muzzle, not the hidden kit barrel.
    local muzzle = turn * v3(entry.mounts.Muzzle) + offset
    for _, attachment in body:GetChildren() do
        if attachment:IsA("Attachment") and attachment ~= handle then
            local p = attachment.CFrame.Position
            local x = attachment == tip and muzzle.X or p.X
            attachment.CFrame = CFrame.new(x, muzzle.Y, muzzle.Z) * attachment.CFrame.Rotation
        end
    end

    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Transparency = 1
        end
    end
    local glow = GLOW_PARTS[name] or {}
    for _, record in manifest.parts do
        local mesh = Instance.new("MeshPart")
        mesh.Name = record.name
        mesh.MeshId = record.meshId
        mesh.Size = v3(record.size)
        -- A multi-part upload records each part's offset from the model pivot (the export's
        -- centre, the frame the mounts are in); a single-part upload sits on the pivot.
        mesh.CFrame = alignment * CFrame.new(record.offset and v3(record.offset) or Vector3.new(0, 0, 0))
        if record.colorMap then
            -- PBR upload (normal, metal and roughness maps): the importer made a SurfaceAppearance.
            mesh.Color = Color3.new(1, 1, 1)
            local surface = Instance.new("SurfaceAppearance")
            surface.ColorMap = record.colorMap
            surface.MetalnessMap = record.metalnessMap or ""
            surface.RoughnessMap = record.roughnessMap or ""
            surface.NormalMap = record.normalMap or ""
            surface.Parent = mesh
        elseif glow[record.name] then
            mesh.Material = Enum.Material.Neon
            mesh.Color = glow[record.name]
            mesh.CastShadow = false
            local light = Instance.new("PointLight")
            light.Name = "GlowLight"
            light.Color = glow[record.name]
            light.Range = GLOW_LIGHT_RANGE
            light.Brightness = GLOW_LIGHT_BRIGHTNESS
            light.Shadows = false
            light.Parent = mesh
            tool:SetAttribute("GlowPart", record.name)
        else
            mesh.TextureID = record.textureId
            local glass = GLASS_PARTS[name] and GLASS_PARTS[name][record.name]
            if glass then
                mesh.Material = Enum.Material.Glass
                mesh.Transparency = glass
                mesh.CastShadow = false
            end
        end
        mesh.Anchored = false
        mesh.CanCollide = false
        mesh.CanTouch = false
        mesh.CanQuery = false
        mesh.Massless = true
        mesh.Parent = model
        local joint = Instance.new("WeldConstraint")
        joint.Name = "ArtWeld"
        joint.Part0 = body
        joint.Part1 = mesh
        joint.Parent = mesh
        if entry.mounts.Core then
            addCoreGlow(model, mesh, alignment, v3(entry.mounts.Core))
        end
    end

    local muzzleGlow = MUZZLE_GLOW[name]
    if muzzleGlow then
        local art = model:FindFirstChild(manifest.parts[1].name)
        local plate = Instance.new("Part")
        plate.Name = "MuzzleGlow"
        plate.Size = muzzleGlow.size
        plate.Material = Enum.Material.Neon
        plate.Color = muzzleGlow.color
        plate.CFrame = alignment * CFrame.new(muzzleGlow.centre)
        plate.Anchored = false
        plate.CanCollide = false
        plate.CanTouch = false
        plate.CanQuery = false
        plate.Massless = true
        plate.CastShadow = false
        plate.Parent = model
        local light = Instance.new("PointLight")
        light.Name = "GlowLight"
        light.Color = muzzleGlow.color
        light.Range = GLOW_LIGHT_RANGE
        light.Brightness = GLOW_LIGHT_BRIGHTNESS
        light.Shadows = false
        light.Parent = plate
        local joint = Instance.new("WeldConstraint")
        joint.Name = "ArtWeld"
        joint.Part0 = art
        joint.Part1 = plate
        joint.Parent = plate
        tool:SetAttribute("GlowPart", plate.Name)
    end
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
    -- Patch: the kit's camera springs WalkSpeed toward its own sprint/aim speed every frame
    -- while a gun is out, overwriting every other speed effect (Brace, pickups). Movement
    -- is ours now (Shared/Movement + MovementController, same 16/24/8 numbers), so switch
    -- the kit's sprint and aim-slow off.
    for _, flag in { "SprintEnabled", "SlowZoomWalkEnabled" } do
        local value = system.Configuration:FindFirstChild(flag)
        assert(value, flag .. " not found in the kit's Configuration; kit changed?")
        value.Value = false
    end
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
    if name == "WhiteSniper" then
        attachWhiteSniperArt(tool)
    elseif REGISTRY_ART[name] then
        attachRegistryArt(tool, name)
    end
    fs.writeFile("assets/weapons/tools/" .. name .. ".rbxm", roblox.serializeModel({ tool }))
    count += 1
end
print("wrote " .. count .. " tools to assets/weapons/tools/")
