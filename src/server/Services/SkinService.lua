-- Applies a player's chosen skin to a weapon Tool when it is handed out, through the
-- Weapons Kit's own hooks. What each system maps to:
--   Texture            recolor/material on the base mesh parts
--   Model              swap the weapon Model for a template in ReplicatedStorage.SkinAssets.Models
--   FireSound          Fired sound id (+ DryFire if the model has one)
--   EquipReloadSound   Reload sound id, Equip sound played on equip
--   ReloadAnimation    Animation registered in the kit's Assets/Animations, Configuration.ReloadAnimation
--   FireEquipAnimation Aim / AimZoom tracks the same way (kit has no fire-anim hook)
--   ProjectileTracer   Configuration.ShotEffect -> a shot effect template (kit built-in name or SkinAssets.Shots)
--   Effects            HitMarkEffect / CasingEffect names, MuzzleFlash sizes
--   Inspect            not supported by the kit yet; recorded on the tool for a future inspect system
-- A system whose assets are still "TODO" is skipped with one warning, so draft skins never break equip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local SkinService = Knit.CreateService({
    Name = "SkinService",
    Client = {},
})

local warned = {}
local function warnOnce(key, msg)
    if not warned[key] then
        warned[key] = true
        warn("[SkinService] " .. msg)
    end
end

-- A reference is ready when it resolves to an asset id (direct id, or an upload:Name that exists)
local function ready(v)
    return Uploads.isReady(v)
end
local function asset(v)
    return Uploads.resolve(v)
end

local function skinReady(skin)
    local texture = skin.Systems.Texture
    if texture and (texture.Body or texture.Overrides) then
        return true
    end
    for _, system in skin.Systems do
        for _, value in system do
            if ready(value) then
                return true
            end
        end
    end
    return false
end

local function attrName(weapon)
    return "Skin_" .. weapon
end

local function toColor(t)
    return Color3.fromRGB(t[1], t[2], t[3])
end

local function setConfig(config, name, class, value)
    local v = config:FindFirstChild(name)
    if v and v.ClassName ~= class then
        v:Destroy()
        v = nil
    end
    if not v then
        v = Instance.new(class)
        v.Name = name
        v.Parent = config
    end
    v.Value = value
end

local function findSound(model, name)
    for _, d in model:GetDescendants() do
        if d:IsA("Sound") and d.Name == name then
            return d
        end
    end
    return nil
end

function SkinService:GetSkin(player, weaponName)
    local id = player:GetAttribute(attrName(weaponName))
    return id and Skins.get(id) or nil
end

-- ===== per-system appliers =====

local function applyTexture(model, tex)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            local rule = tex.Overrides and tex.Overrides[part.Name] or tex.Body
            if rule then
                if rule.Color then
                    part.Color = toColor(rule.Color)
                end
                if rule.Material and Enum.Material[rule.Material] then
                    part.Material = Enum.Material[rule.Material]
                end
                if rule.Reflectance then
                    part.Reflectance = rule.Reflectance
                end
                if part:IsA("MeshPart") then
                    -- pattern image (camo, stripes) if the skin has one and it is uploaded; else flat colour
                    part.TextureID = asset(tex.Asset) or ""
                end
            end
        end
    end
end

local function applyModel(tool, model, sys, skinId)
    if not ready(sys.Template) then
        warnOnce(skinId .. ":Model", skinId .. " Model template not ready; keeping base mesh")
        return model
    end
    local folder = ReplicatedStorage:FindFirstChild("SkinAssets")
    local template = folder and folder:FindFirstChild("Models") and folder.Models:FindFirstChild(sys.Template)
    if not template then
        warnOnce(
            skinId .. ":Model",
            skinId .. " Model template '" .. sys.Template .. "' not found in SkinAssets.Models"
        )
        return model
    end
    local replacement = template:Clone()
    -- The kit needs these to weld and fire; refuse a template that lacks them
    local hasTip, hasHandle = false, false
    for _, d in replacement:GetDescendants() do
        if d:IsA("Attachment") then
            hasTip = hasTip or d.Name == "TipAttachment"
            hasHandle = hasHandle or d.Name == "HandleAttachment"
        end
    end
    if not (hasTip and hasHandle and replacement.PrimaryPart) then
        warnOnce(skinId .. ":Model", skinId .. " template needs PrimaryPart, TipAttachment and HandleAttachment")
        replacement:Destroy()
        return model
    end
    -- carry over the base sounds unless the skin replaces them, so nothing goes silent
    for _, name in { "Fired", "Reload" } do
        local base = findSound(model, name)
        if base and not findSound(replacement, name) then
            base:Clone().Parent = replacement.PrimaryPart
        end
    end
    replacement.Name = model.Name
    replacement.Parent = tool
    model:Destroy()
    return replacement
end

local function applyFireSound(model, sys, skinId)
    local fired = findSound(model, "Fired")
    if fired and ready(sys.Fire) then
        fired.SoundId = asset(sys.Fire)
    elseif not ready(sys.Fire) then
        warnOnce(skinId .. ":FireSound", skinId .. " FireSound not ready")
    end
    local dry = findSound(model, "DryFire")
    if dry and ready(sys.DryFire) then
        dry.SoundId = asset(sys.DryFire)
    end
end

local function applyEquipReloadSound(tool, model, sys, skinId)
    local reload = findSound(model, "Reload")
    local stage = type(sys.ReloadStages) == "table" and sys.ReloadStages[1] or nil
    if reload and ready(stage) then
        reload.SoundId = asset(stage)
    elseif not ready(stage) then
        warnOnce(skinId .. ":EquipReloadSound", skinId .. " reload sound not ready")
    end
    if ready(sys.Equip) and model.PrimaryPart then
        local equip = Instance.new("Sound")
        equip.Name = "SkinEquip"
        equip.SoundId = asset(sys.Equip)
        equip.Volume = 0.6
        equip.Parent = model.PrimaryPart
        tool.Equipped:Connect(function()
            equip:Play()
        end)
    end
end

local function registerAnimation(systemFolder, name, assetId)
    local anims = systemFolder:FindFirstChild("Assets") and systemFolder.Assets:FindFirstChild("Animations")
    if not anims then
        return nil
    end
    local existing = anims:FindFirstChild(name)
    if existing then
        return name
    end
    local anim = Instance.new("Animation")
    anim.Name = name
    anim.AnimationId = assetId
    anim.Parent = anims
    return name
end

local function applyReloadAnimation(config, systemFolder, sys, skinId)
    local id = sys.ThirdPerson or sys.Animation
    if not ready(id) then
        warnOnce(skinId .. ":ReloadAnimation", skinId .. " reload animation not ready")
        return
    end
    local name = registerAnimation(systemFolder, skinId .. "_Reload", asset(id))
    if name then
        setConfig(config, "ReloadAnimation", "StringValue", name)
    end
end

local function applyFireEquipAnimation(config, systemFolder, sys, skinId)
    -- Kit exposes aim tracks by name; fire/equip/sprint motions have no hook yet.
    if ready(sys.Idle) then
        local name = registerAnimation(systemFolder, skinId .. "_Aim", asset(sys.Idle))
        if name then
            setConfig(config, "AimTrack", "StringValue", name)
        end
    end
    if ready(sys.Aim) then
        local name = registerAnimation(systemFolder, skinId .. "_AimZoom", asset(sys.Aim))
        if name then
            setConfig(config, "AimZoomTrack", "StringValue", name)
        end
    end
end

local function ensureShotEffect(systemFolder, name)
    local shots = systemFolder.Assets.Effects:FindFirstChild("Shots")
    if not shots then
        return false
    end
    if shots:FindFirstChild(name) then
        return true
    end
    local folder = ReplicatedStorage:FindFirstChild("SkinAssets")
    local template = folder and folder:FindFirstChild("Shots") and folder.Shots:FindFirstChild(name)
    if template then
        template:Clone().Parent = shots
        return true
    end
    return false
end

local function applyProjectileTracer(config, systemFolder, sys, skinId)
    local effect = sys.ShotEffect or sys.Tracer or sys.Projectile
    if not ready(effect) then
        warnOnce(skinId .. ":ProjectileTracer", skinId .. " shot effect not ready")
        return
    end
    if ensureShotEffect(systemFolder, effect) then
        setConfig(config, "ShotEffect", "StringValue", effect)
    else
        warnOnce(skinId .. ":ProjectileTracer", skinId .. " shot effect '" .. effect .. "' not found")
    end
end

local function applyEffects(config, sys)
    if ready(sys.HitMark) then
        setConfig(config, "HitMarkEffect", "StringValue", sys.HitMark)
    end
    if ready(sys.Casing) then
        setConfig(config, "CasingEffect", "StringValue", sys.Casing)
    end
    if type(sys.MuzzleFlashSize) == "table" then
        setConfig(config, "MuzzleFlashSize0", "NumberValue", sys.MuzzleFlashSize[1])
        setConfig(config, "MuzzleFlashSize1", "NumberValue", sys.MuzzleFlashSize[2])
    end
end

-- ===== entry point =====

function SkinService:Apply(tool, player)
    local skin = self:GetSkin(player, tool.Name)
    if not skin then
        return
    end
    local model = tool:FindFirstChildOfClass("Model")
    local config = tool:FindFirstChild("Configuration")
    if not model or not config then
        return
    end
    local systemFolder = ReplicatedStorage:FindFirstChild("WeaponsSystem")
    tool:SetAttribute("Skin", skin.Id)
    local sys = skin.Systems

    if sys.Model then
        model = applyModel(tool, model, sys.Model, skin.Id)
    end
    if sys.Texture and (sys.Texture.Body or sys.Texture.Overrides) then
        applyTexture(model, sys.Texture)
    end
    if sys.FireSound then
        applyFireSound(model, sys.FireSound, skin.Id)
    end
    if sys.EquipReloadSound then
        applyEquipReloadSound(tool, model, sys.EquipReloadSound, skin.Id)
    end
    if systemFolder then
        if sys.ReloadAnimation then
            applyReloadAnimation(config, systemFolder, sys.ReloadAnimation, skin.Id)
        end
        if sys.FireEquipAnimation then
            applyFireEquipAnimation(config, systemFolder, sys.FireEquipAnimation, skin.Id)
        end
        if sys.ProjectileTracer then
            applyProjectileTracer(config, systemFolder, sys.ProjectileTracer, skin.Id)
        end
    end
    if sys.Effects then
        applyEffects(config, sys.Effects)
    end
    if sys.Inspect then
        tool:SetAttribute("InspectAnimation", sys.Inspect.Animation)
    end
end

-- Client picks a skin for a weapon (or nil to clear). Only valid registered skins are accepted.
function SkinService.Client:SetSkin(player, weaponName, skinId)
    if player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed" then
        return false, "match_locked"
    end
    if type(weaponName) ~= "string" then
        return false, "invalid_weapon"
    end
    if skinId == nil then
        player:SetAttribute(attrName(weaponName), nil)
    else
        local skin = Skins.get(skinId)
        if not skin or skin.Weapon ~= weaponName then
            return false
        end
        if not skinReady(skin) then
            return false, "unavailable_item"
        end
        player:SetAttribute(attrName(weaponName), skinId)
    end
    Knit.GetService("WeaponService"):GiveLoadout(player)
    return true
end

function SkinService.Client:GetSkins(player, weaponName)
    local out = {}
    for _, s in Skins.forWeapon(weaponName) do
        -- Ready = something will visibly change today (texture rules, or any non-TODO asset)
        table.insert(out, { Id = s.Id, Tier = s.Tier, Concept = s.Concept, Ready = skinReady(s) })
    end
    return out, player:GetAttribute(attrName(weaponName))
end

return SkinService
