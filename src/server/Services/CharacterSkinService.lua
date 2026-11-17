-- Player-selectable, match-only R15 armor skins. Weapon skins and Tools remain
-- separate. Returning to the lobby reloads the player's usual avatar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Definitions = require(ReplicatedStorage.Shared.CharacterSkins.Definitions)
local Visuals = require(ReplicatedStorage.Shared.CharacterSkins.Visuals)

local CharacterSkinService = Knit.CreateService({ Name = "CharacterSkinService", Client = {} })

function CharacterSkinService.Client:GetOptions(player)
    local options = {}
    for id, definition in Definitions do
        table.insert(options, { Id = id, Name = definition.name })
    end
    table.sort(options, function(a, b)
        return a.Name < b.Name
    end)
    return options, player:GetAttribute("CharacterSkin") or ""
end

function CharacterSkinService.Client:Select(player, id)
    if player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed" then
        return false, "match_locked"
    end
    if type(id) ~= "string" or (id ~= "" and not Definitions[id]) then
        return false, "unknown_skin"
    end
    player:SetAttribute("CharacterSkin", id)
    return true
end

function CharacterSkinService:KnitStart()
    local function watch(player)
        player.CharacterAdded:Connect(function(character)
            task.defer(function()
                local humanoid = character:WaitForChild("Humanoid", 10)
                if not humanoid then
                    return
                end
                -- Appearance and accessories arrive after CharacterAdded.
                task.wait(0.5)
                if character.Parent and player:GetAttribute("InMatch") then
                    local id = player:GetAttribute("CharacterSkin")
                    if type(id) == "string" and Definitions[id] then
                        Visuals.apply(character, id)
                    end
                end
            end)
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
end

return CharacterSkinService
