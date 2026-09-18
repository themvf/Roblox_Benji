-- Applies a player's chosen skin to a weapon Tool when it is handed out.
-- Only systems the Weapons Kit can take at runtime are applied today:
--   Texture  recolor/material on the base mesh
--   Model    swap the weapon Model for an asset (when Asset is a real id)
-- Sounds, animations, projectiles and effects are read from the same package
-- once art delivers them; the validator already guarantees their shape.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Skins = require(ReplicatedStorage.Shared.Skins)

local SkinService = Knit.CreateService({
    Name = "SkinService",
    Client = {},
})

local function attrName(weapon)
    return "Skin_" .. weapon
end

function SkinService:GetSkin(player, weaponName)
    local id = player:GetAttribute(attrName(weaponName))
    return id and Skins.get(id) or nil
end

local function toColor(t)
    return Color3.fromRGB(t[1], t[2], t[3])
end

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
                if part:IsA("MeshPart") then
                    part.TextureID = "" -- flat color reads better than a tinted texture
                end
            end
        end
    end
end

function SkinService:Apply(tool, player)
    local skin = self:GetSkin(player, tool.Name)
    if not skin then
        return
    end
    local model = tool:FindFirstChildOfClass("Model")
    if not model then
        return
    end
    tool:SetAttribute("Skin", skin.Id)
    local sys = skin.Systems
    if sys.Texture and (sys.Texture.Body or sys.Texture.Overrides) then
        applyTexture(model, sys.Texture)
    end
    -- Model/sound/animation/effect swaps plug in here as assets arrive.
end

-- Client picks a skin for a weapon (or nil to clear). Only valid registered skins are accepted.
function SkinService.Client:SetSkin(player, weaponName, skinId)
    if skinId == nil then
        player:SetAttribute(attrName(weaponName), nil)
    else
        local skin = Skins.get(skinId)
        if not skin or skin.Weapon ~= weaponName then
            return false
        end
        player:SetAttribute(attrName(weaponName), skinId)
    end
    if not player:GetAttribute("InMatch") then
        Knit.GetService("WeaponService"):GiveLoadout(player)
    end
    return true
end

function SkinService.Client:GetSkins(_player, weaponName)
    local out = {}
    for _, s in Skins.forWeapon(weaponName) do
        table.insert(out, { Id = s.Id, Tier = s.Tier, Concept = s.Concept })
    end
    return out
end

return SkinService
