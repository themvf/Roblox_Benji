-- AlterEgoService: selection, validation, spawn integration, current Alter Ego state.
-- Selection persists as the AlterEgo attribute (DataService mirrors it). Titan is the only ego in v1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)

local AlterEgoService = Knit.CreateService({
    Name = "AlterEgoService",
    Client = {},
})

function AlterEgoService:Get(player)
    local id = player:GetAttribute("AlterEgo")
    if not id or not AlterEgos.get(id) then
        id = AlterEgos.DEFAULT
    end
    return id, AlterEgos.get(id)
end

function AlterEgoService.Client:GetOptions(_player)
    local out = {}
    for id, ego in AlterEgos.List do
        table.insert(out, { Id = id, Name = ego.Name, Tagline = ego.Tagline, Mutant = ego.Mutant })
    end
    table.sort(out, function(a, b)
        return a.Id < b.Id
    end)
    return out
end

function AlterEgoService.Client:Get(player)
    local id = AlterEgoService:Get(player)
    return id
end

function AlterEgoService.Client:Select(player, id)
    if not AlterEgos.get(id) then
        return false
    end
    if player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed" then
        return false -- lobby only
    end
    player:SetAttribute("AlterEgo", id)
    return true
end

-- Spawn integration: the Alter Ego's base look (shoulder plates for Titan) on every character
local function dress(character, ego)
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if not torso or character:FindFirstChild("EgoMark") then
        return
    end
    for _, side in { -1, 1 } do
        local plate = Instance.new("Part")
        plate.Name = "EgoMark"
        plate.Size = Vector3.new(1.4, 0.6, 1.4)
        plate.Color = ego.Color
        plate.Material = Enum.Material.Metal
        plate.CanCollide = false
        plate.Massless = true
        plate.CFrame = torso.CFrame * CFrame.new(side * 1.1, 0.9, 0)
        local weld = Instance.new("Weld")
        weld.Part0 = torso
        weld.Part1 = plate
        weld.C0 = CFrame.new(side * 1.1, 0.9, 0)
        weld.Parent = plate
        plate.Parent = character
    end
end

function AlterEgoService:KnitStart()
    local function watch(player)
        player.CharacterAdded:Connect(function(character)
            character:WaitForChild("Humanoid")
            task.wait(0.2)
            local _, ego = self:Get(player)
            if ego and character.Parent then
                dress(character, ego)
            end
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return AlterEgoService
