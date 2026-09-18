-- Skin validator: the Weapon & Skin Design Spec as code. Pure Luau, no Roblox APIs,
-- so it runs in Lune at build time (tools/check_skins.luau) and in the game at runtime.
--
-- A skin is a table:
--   Id        "skn_<weapon>_<tier>_<concept>"  (tier short: common | rare | leg | myth)
--   Weapon    name in Shared/Weapons
--   Tier      "Common" | "Rare" | "Legendary" | "Mythical"
--   Concept   one sentence; the concept word in the Id must appear in it
--   Materials { Primary = string, Accent = string }
--   SoundPalette string
--   Systems   { [SystemName] = table }  -- a system present = fully replaced
local Validate = {}

Validate.SYSTEMS = {
    "Model",
    "Texture",
    "FireSound",
    "EquipReloadSound",
    "ReloadAnimation",
    "FireEquipAnimation",
    "ProjectileTracer",
    "Effects",
    "Inspect",
}

-- Rarity tiers: what each may replace and must replace.
Validate.TIERS = {
    {
        Name = "Common",
        Short = "common",
        May = { "Model", "Texture" },
        MustOneOf = { "Model", "Texture" },
        MaxSystems = 1,
    },
    {
        Name = "Rare",
        Short = "rare",
        May = { "Model", "Texture", "FireSound", "ProjectileTracer" },
        MustOneOf = { "Model", "Texture" },
        MustAlsoOneOf = { "FireSound", "ProjectileTracer" },
        MaxSystems = 3,
    },
    {
        Name = "Legendary",
        Short = "leg",
        May = {
            "Model",
            "Texture",
            "FireSound",
            "EquipReloadSound",
            "ReloadAnimation",
            "FireEquipAnimation",
            "ProjectileTracer",
            "Effects",
        },
        Must = { "Model", "FireSound", "ReloadAnimation", "Effects" },
    },
    {
        Name = "Mythical",
        Short = "myth",
        May = Validate.SYSTEMS,
        Must = Validate.SYSTEMS,
    },
}

-- Guardrail: a skin never changes a gameplay number. Any of these keys anywhere in a skin is an error.
Validate.FORBIDDEN_KEYS = {
    "Damage",
    "Crit",
    "HitDamage",
    "Cooldown",
    "ShotCooldown",
    "FireRate",
    "Spread",
    "MinSpread",
    "MaxSpread",
    "Recoil",
    "RecoilMin",
    "RecoilMax",
    "Range",
    "MaxDistance",
    "DropoffStart",
    "DropoffEnd",
    "FullDamageDistance",
    "ZeroDamageDistance",
    "Reload",
    "ReloadTime",
    "EmptyReload",
    "Ammo",
    "AmmoCapacity",
    "MagSize",
    "ADS",
    "AimTime",
    "MoveSpeed",
    "BulletSpeed",
    "ProjectileSpeed",
    "GravityFactor",
    "Hitbox",
    "EquipTime",
    "StartupTime",
    "Burst",
    "BurstDelay",
    "Pellets",
    "NumProjectiles",
}

local function has(list, v)
    return table.find(list, v) ~= nil
end

local function tierByName(name)
    for _, t in Validate.TIERS do
        if t.Name == name then
            return t
        end
    end
    return nil
end

-- Lowest tier whose May set admits every system the skin touches and whose Must rules are met.
function Validate.minimalTier(systems)
    for _, tier in Validate.TIERS do
        local ok = true
        for _, sys in systems do
            if not has(tier.May, sys) then
                ok = false
                break
            end
        end
        if ok and tier.MaxSystems and #systems > tier.MaxSystems then
            ok = false
        end
        if ok then
            return tier
        end
    end
    return nil
end

local function findForbidden(tbl, path, out, depth)
    if depth > 6 or type(tbl) ~= "table" then
        return
    end
    for k, v in tbl do
        if type(k) == "string" and has(Validate.FORBIDDEN_KEYS, k) then
            table.insert(out, path .. "." .. k)
        end
        findForbidden(v, path .. "." .. tostring(k), out, depth + 1)
    end
end

-- Returns (ok: boolean, errors: {string}, info: table)
function Validate.check(skin, weapons)
    local errors = {}
    local function fail(msg)
        table.insert(errors, msg)
    end
    if type(skin) ~= "table" then
        return false, { "skin is not a table" }, {}
    end

    -- Basics
    if type(skin.Id) ~= "string" then
        fail("Id missing")
    end
    if type(skin.Weapon) ~= "string" or (weapons and not weapons[skin.Weapon]) then
        fail("Weapon missing or unknown: " .. tostring(skin.Weapon))
    end
    local tier = type(skin.Tier) == "string" and tierByName(skin.Tier) or nil
    if not tier then
        fail("Tier must be Common, Rare, Legendary or Mythical; got " .. tostring(skin.Tier))
    end
    if type(skin.Concept) ~= "string" or #skin.Concept < 10 then
        fail("Concept sentence missing")
    end
    if type(skin.Materials) ~= "table" or not skin.Materials.Primary or not skin.Materials.Accent then
        fail("Materials story needs Primary and Accent")
    end
    if type(skin.SoundPalette) ~= "string" then
        fail("SoundPalette missing")
    end

    -- Systems
    local systems = {}
    if type(skin.Systems) ~= "table" then
        fail("Systems table missing")
    else
        for name, def in skin.Systems do
            if not has(Validate.SYSTEMS, name) then
                fail("Unknown system: " .. tostring(name))
            elseif type(def) ~= "table" then
                fail("System " .. name .. " must be a table (a system is replaced fully or not at all)")
            else
                table.insert(systems, name)
            end
        end
    end
    table.sort(systems)
    if #systems == 0 then
        fail("A skin must replace at least one system")
    end

    -- Guardrail: no gameplay numbers anywhere
    local forbidden = {}
    findForbidden(skin.Systems or {}, "Systems", forbidden, 0)
    for _, path in forbidden do
        fail("Gameplay value in a skin is forbidden: " .. path)
    end

    -- Tier placement: must be the lowest tier that admits everything
    local minimal = Validate.minimalTier(systems)
    if tier and minimal then
        if tier.Name ~= minimal.Name then
            fail(
                ("Tier is %s but the lowest admitting tier is %s (a skin is placed in the lowest tier that admits everything it touches)"):format(
                    tier.Name,
                    minimal.Name
                )
            )
        end
    elseif tier and not minimal then
        fail("No tier admits this system set: " .. table.concat(systems, ", "))
    end

    -- Tier must-replace rules
    if tier then
        if tier.Must then
            for _, sys in tier.Must do
                if not has(systems, sys) then
                    fail(tier.Name .. " must replace " .. sys)
                end
            end
        end
        if tier.MustOneOf then
            local any = false
            for _, sys in tier.MustOneOf do
                if has(systems, sys) then
                    any = true
                end
            end
            if not any then
                fail(tier.Name .. " must replace one of " .. table.concat(tier.MustOneOf, " or "))
            end
        end
        if tier.MustAlsoOneOf then
            local any = false
            for _, sys in tier.MustAlsoOneOf do
                if has(systems, sys) then
                    any = true
                end
            end
            if not any then
                fail(tier.Name .. " must also replace one of " .. table.concat(tier.MustAlsoOneOf, " or "))
            end
        end
    end

    -- Naming: skn_<weapon>_<tier>_<concept>, concept one word found in the sentence
    if type(skin.Id) == "string" and tier and type(skin.Weapon) == "string" then
        local w, t, c = skin.Id:match("^skn_([a-z0-9]+)_([a-z]+)_([a-z0-9]+)$")
        if not w then
            fail("Id must look like skn_<weapon>_<tier>_<concept> (lowercase, one word each): " .. skin.Id)
        else
            if w ~= skin.Weapon:lower() then
                fail("Id weapon segment '" .. w .. "' does not match Weapon " .. skin.Weapon)
            end
            if t ~= tier.Short then
                fail("Id tier segment '" .. t .. "' should be '" .. tier.Short .. "' for " .. tier.Name)
            end
            if type(skin.Concept) == "string" and not skin.Concept:lower():find(c, 1, true) then
                fail("Concept word '" .. c .. "' does not appear in the concept sentence")
            end
        end
    end

    -- Model system keeps the silhouette: record the declared deviation for the read test
    local model = skin.Systems and skin.Systems.Model
    if type(model) == "table" and model.SilhouetteDeviation and model.SilhouetteDeviation > 0.15 then
        fail("Model silhouette deviation over 15%: " .. tostring(model.SilhouetteDeviation))
    end

    return #errors == 0, errors, { Systems = systems, MinimalTier = minimal and minimal.Name or nil }
end

return Validate
