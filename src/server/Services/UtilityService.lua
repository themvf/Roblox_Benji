-- Utility slot items. Today: the Jetpack. The Tool in the hand is a small remote; when it is
-- equipped the server welds the pack model to the character's back and mirrors the client's
-- Thrusting attribute into the pack's flame emitters so everyone sees the burn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local UtilityService = Knit.CreateService({
    Name = "UtilityService",
    Client = {},
})

local packs = {} -- [character] = pack model

local function attachPack(character, tool)
    local stats = Weapons[tool.Name]
    if not stats or stats.Type ~= "Utility" then
        return
    end
    local template = tool:FindFirstChild("Pack")
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if not template or not torso then
        return
    end
    local pack = template:Clone()
    pack.Name = "JetpackPack"
    for _, d in pack:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.Massless = true
        end
    end
    local root = pack.PrimaryPart or pack:FindFirstChildWhichIsA("BasePart")
    pack:PivotTo(torso.CFrame * CFrame.new(0, 0.2, 0.9))
    local weld = Instance.new("Weld")
    weld.Part0 = torso
    weld.Part1 = root
    weld.C0 = CFrame.new(0, 0.2, 0.9)
    weld.Parent = root
    pack.Parent = character
    packs[character] = pack
end

local function detachPack(character)
    local pack = packs[character]
    if pack then
        pack:Destroy()
        packs[character] = nil
    end
end

-- Client tells us when it starts/stops burning; we flip the emitters so others see it.
function UtilityService.Client:SetThrusting(player, on)
    local character = player.Character
    local pack = character and packs[character]
    if not pack then
        return
    end
    for _, d in pack:GetDescendants() do
        if d:IsA("ParticleEmitter") then
            d.Enabled = on == true
        end
    end
    character:SetAttribute("Thrusting", on == true or nil)
end

function UtilityService:KnitStart()
    local function watch(player)
        player.CharacterAdded:Connect(function(character)
            character.ChildAdded:Connect(function(child)
                if child:IsA("Tool") and child:GetAttribute("WeaponClass") == "Utility" then
                    attachPack(character, child)
                end
            end)
            character.ChildRemoved:Connect(function(child)
                if child:IsA("Tool") and child:GetAttribute("WeaponClass") == "Utility" then
                    detachPack(character)
                end
            end)
            character.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    packs[character] = nil
                end
            end)
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return UtilityService
