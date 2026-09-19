-- Persistent player data via ProfileStore (MadStudioRoblox). One profile per player:
--   Loadout   { Primary, Secondary, Melee, Utility }
--   Favorites "id,id,id" (celebrations)
--   Skins     { [WeaponName] = skinId }
--   Stats     { Wins, Kills, Matches }
-- The rest of the game reads and writes player attributes as before; this service loads
-- the profile into attributes on join and mirrors attribute changes back into the profile.
-- In Studio without API access ProfileStore falls back to a mock store automatically.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ProfileStore = require(ServerScriptService.Server.ProfileStore)

local DataService = Knit.CreateService({ Name = "DataService" })

local TEMPLATE = {
    Loadout = {},
    Favorites = "",
    Skins = {},
    Stats = {
        Wins = 0,
        Losses = 0,
        Kills = 0,
        Deaths = 0,
        Assists = 0,
        Captures = 0,
        Matches = 0,
        MVPs = 0,
        ObjectiveScore = 0,
        BountiesClaimed = 0,
        BountiesSurvived = 0,
        XP = 0,
        Level = 1,
        CurrentStreak = 0,
        BestStreak = 0,
    },
    StreakCheckpoints = "",
}

local STORE_NAME = "PlayerData_v1"
local SLOTS = { "Primary", "Secondary", "Melee", "Utility" }
local STATS = {
    "Wins",
    "Losses",
    "Kills",
    "Deaths",
    "Assists",
    "Captures",
    "Matches",
    "MVPs",
    "ObjectiveScore",
    "BountiesClaimed",
    "BountiesSurvived",
    "XP",
    "Level",
    "CurrentStreak",
    "BestStreak",
}

local profiles = {} -- [player] = profile

local function applyToAttributes(player, data)
    for _, slot in SLOTS do
        player:SetAttribute("Loadout" .. slot, data.Loadout[slot] or "")
    end
    player:SetAttribute("CelebrationFavorites", data.Favorites or "")
    for weapon, skinId in data.Skins do
        player:SetAttribute("Skin_" .. weapon, skinId)
    end
    for _, stat in STATS do
        player:SetAttribute(stat, data.Stats[stat] or 0)
    end
    player:SetAttribute("StreakCheckpoints", data.StreakCheckpoints or "")
    local tier = require(ReplicatedStorage.Shared.Progression).streakTier(data.Stats.CurrentStreak or 0)
    player:SetAttribute("StreakStatus", tier and tier.Name or "")
end

local function mirrorAttribute(player, data, name)
    local value = player:GetAttribute(name)
    local slot = name:match("^Loadout(%a+)$")
    if slot and table.find(SLOTS, slot) then
        data.Loadout[slot] = (value ~= "" and value) or nil
        return
    end
    if name == "CelebrationFavorites" then
        data.Favorites = value or ""
        return
    end
    local weapon = name:match("^Skin_(.+)$")
    if weapon then
        data.Skins[weapon] = value
        return
    end
    if table.find(STATS, name) and type(value) == "number" then
        data.Stats[name] = value
        return
    end
    if name == "StreakCheckpoints" and type(value) == "string" then
        data.StreakCheckpoints = value
    end
end

function DataService:GetProfile(player)
    return profiles[player]
end

local function onPlayer(self, player)
    local profile = self.Store:StartSessionAsync("p_" .. player.UserId, {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })
    if not profile then
        player:Kick("Could not load your data. Please rejoin.")
        return
    end
    profile:AddUserId(player.UserId)
    profile:Reconcile()
    profile.OnSessionEnd:Connect(function()
        profiles[player] = nil
        if player.Parent == Players then
            player:Kick("Your data was opened elsewhere. Please rejoin.")
        end
    end)
    if player.Parent ~= Players then
        profile:EndSession()
        return
    end
    profiles[player] = profile

    applyToAttributes(player, profile.Data)
    player.AttributeChanged:Connect(function(name)
        if profiles[player] == profile then
            mirrorAttribute(player, profile.Data, name)
        end
    end)
    player:SetAttribute("DataLoaded", true)
end

function DataService:KnitInit()
    self.Store = ProfileStore.New(STORE_NAME, TEMPLATE)
    if ProfileStore.DataStoreState ~= "Access" then
        task.delay(5, function()
            if ProfileStore.DataStoreState ~= "Access" then
                warn(
                    "[DataService] DataStore state is "
                        .. ProfileStore.DataStoreState
                        .. "; using ProfileStore's mock store (Studio without API access). Saves will not persist."
                )
            end
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        onPlayer(self, player)
    end)
    for _, p in Players:GetPlayers() do
        task.spawn(onPlayer, self, p)
    end
    Players.PlayerRemoving:Connect(function(player)
        local profile = profiles[player]
        if profile then
            profile:EndSession()
        end
    end)
end

return DataService
