-- Stores each player's chosen primary and secondary as attributes and validates picks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local LoadoutService = Knit.CreateService({
    Name = "LoadoutService",
    Client = {},
})

local DEFAULT = { Primary = "AssaultRifle", Secondary = "Handgun" }

local function available()
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local out = { Primary = {}, Secondary = {} }
    if not tools then
        return out
    end
    for _, tool in tools:GetChildren() do
        local stats = Weapons[tool.Name]
        if stats and out[stats.Slot] then
            table.insert(out[stats.Slot], tool.Name)
        end
    end
    table.sort(out.Primary)
    table.sort(out.Secondary)
    return out
end

function LoadoutService:Get(player)
    return {
        Primary = player:GetAttribute("LoadoutPrimary") or DEFAULT.Primary,
        Secondary = player:GetAttribute("LoadoutSecondary") or DEFAULT.Secondary,
    }
end

function LoadoutService.Client:GetOptions(_player)
    return available()
end

function LoadoutService.Client:GetLoadout(player)
    return self.Server:Get(player)
end

-- Returns the saved loadout, or nil if a pick was invalid.
function LoadoutService.Client:SetLoadout(player, primary, secondary)
    local options = available()
    if not table.find(options.Primary, primary) or not table.find(options.Secondary, secondary) then
        return nil
    end
    player:SetAttribute("LoadoutPrimary", primary)
    player:SetAttribute("LoadoutSecondary", secondary)

    -- In the lobby, swap weapons right away so the player can try them.
    if not player:GetAttribute("InMatch") then
        Knit.GetService("WeaponService"):GiveLoadout(player)
    end
    return self.Server:Get(player)
end

return LoadoutService
