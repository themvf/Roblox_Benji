-- Stores each player's chosen primary and secondary as attributes and validates picks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local LoadoutService = Knit.CreateService({
    Name = "LoadoutService",
    Client = {},
})

local DEFAULT = { Primary = "AssaultRifle", Secondary = "Handgun", Melee = "Katana", Utility = nil }
local EMPTY = "__NONE__"
local SLOTS = Weapons.SLOTS

local function matchLocked(player)
    return player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed"
end

local function available()
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local out = {}
    for _, slot in SLOTS do
        out[slot] = {}
    end
    if not tools then
        return out
    end
    for _, tool in tools:GetChildren() do
        local stats = Weapons[tool.Name]
        if stats and out[stats.Slot] then
            table.insert(out[stats.Slot], tool.Name)
        end
    end
    for _, slot in SLOTS do
        table.sort(out[slot])
    end
    return out
end

function LoadoutService:Get(player)
    local out = {}
    for _, slot in SLOTS do
        local v = player:GetAttribute("Loadout" .. slot)
        if v == EMPTY then
            v = nil
        elseif v == "" then
            v = DEFAULT[slot]
        end
        out[slot] = v
    end
    return out
end

function LoadoutService.Client:GetOptions(_player)
    return available()
end

function LoadoutService.Client:GetLoadout(player)
    return self.Server:Get(player)
end

-- Change one slot without resending a possibly stale draft of every other slot.
-- Lobby and queue edits are allowed; InMatch is the authoritative commit boundary.
function LoadoutService.Client:SetSlot(player, slot, pick)
    if matchLocked(player) then
        return false, "match_locked", self.Server:Get(player)
    end
    if not table.find(SLOTS, slot) then
        return false, "invalid_slot", self.Server:Get(player)
    end

    local required = slot == "Primary" or slot == "Secondary"
    if pick == nil and required then
        return false, "required_slot", self.Server:Get(player)
    end
    local options = available()
    if pick ~= nil and not table.find(options[slot], pick) then
        return false, "unavailable_item", self.Server:Get(player)
    end

    player:SetAttribute("Loadout" .. slot, pick or EMPTY)
    Knit.GetService("WeaponService"):GiveLoadout(player)
    return true, nil, self.Server:Get(player)
end

-- picks = { Primary = name, Secondary = name, Melee = name?, Utility = name? }
-- Returns the saved loadout, or nil if a pick was invalid. Primary and Secondary are required.
function LoadoutService.Client:SetLoadout(player, picks)
    if type(picks) ~= "table" then
        return nil
    end
    if matchLocked(player) then
        return nil
    end
    local options = available()
    for _, slot in SLOTS do
        local pick = picks[slot]
        local required = slot == "Primary" or slot == "Secondary"
        if pick ~= nil and not table.find(options[slot], pick) then
            return nil
        end
        if required and pick == nil then
            return nil
        end
    end
    for _, slot in SLOTS do
        player:SetAttribute("Loadout" .. slot, picks[slot] or EMPTY)
    end

    -- In the lobby, swap weapons right away so the player can try them.
    if not player:GetAttribute("InMatch") then
        Knit.GetService("WeaponService"):GiveLoadout(player)
    end
    return self.Server:Get(player)
end

return LoadoutService
