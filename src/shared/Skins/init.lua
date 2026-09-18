-- Skin registry. Every module under Registry/ is one skin; see Validate.lua for the shape.
-- At runtime (Roblox) this requires the child ModuleScripts; in Lune the build script
-- reads the files directly.
local Skins = {}

Skins.Validate = require(script.Validate)

local all = {}
local byId = {}
local byWeapon = {}

local registry = script:FindFirstChild("Registry")
if registry then
    for _, mod in registry:GetChildren() do
        if mod:IsA("ModuleScript") then
            local skin = require(mod)
            table.insert(all, skin)
            byId[skin.Id] = skin
            byWeapon[skin.Weapon] = byWeapon[skin.Weapon] or {}
            table.insert(byWeapon[skin.Weapon], skin)
        end
    end
end

function Skins.all()
    return all
end

function Skins.get(id)
    return byId[id]
end

function Skins.forWeapon(weaponName)
    return byWeapon[weaponName] or {}
end

return Skins
