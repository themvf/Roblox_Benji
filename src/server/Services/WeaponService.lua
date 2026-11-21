-- Bridges Roblox's Weapons Kit (ServerScriptService/WeaponsSystem) with our game:
--   * team check uses the Team attribute set by RoundService
--   * headshots deal Rivals crit damage
--   * players receive their loadout on spawn
-- Firing, bullets, recoil, reloads, GUI, and the shoulder camera are all the kit's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local WeaponService = Knit.CreateService({ Name = "WeaponService" })

local TEAM_IDS = { Red = 1, Blue = 2, Lobby = 3 }

local function teamOf(player)
    return TEAM_IDS[player:GetAttribute("Team")] or 0 -- 0 = no team, can hit anyone
end

local function onDamage(_system, target, amount, _damageType, dealer, hitInfo, weaponInstance)
    if not target:IsA("Humanoid") then
        return
    end
    if target.Parent and target.Parent:GetAttribute("IsVehicle") then
        local dealerTeam = dealer and dealer:IsA("Player") and dealer:GetAttribute("Team")
        local vehicleTeam = target.Parent:GetAttribute("DriverTeam")
        if dealerTeam and vehicleTeam and dealerTeam == vehicleTeam then
            return
        end
        target:TakeDamage(amount)
        return
    end
    if dealer and dealer:IsA("Player") and target.Parent then
        target.Parent:SetAttribute("LastHitBy", dealer.UserId)
        target.Parent:SetAttribute("LastHitByName", dealer.Name)
        target.Parent:SetAttribute("LastHitAt", os.clock())
    end
    local part = hitInfo and hitInfo.part
    local config = weaponInstance and weaponInstance:FindFirstChild("Configuration")
    local fraction = config and config:FindFirstChild("DamageFractionOfMaxHealth")
    if fraction and fraction:IsA("NumberValue") then
        amount = target.MaxHealth * fraction.Value
    end
    if part and part.Name == "Head" and weaponInstance then
        local crit = config and config:FindFirstChild("CritMultiplier")
        if crit then
            amount *= crit.Value
        end
    end
    local attackerRoot = dealer
        and dealer:IsA("Player")
        and dealer.Character
        and dealer.Character:FindFirstChild("HumanoidRootPart")
    amount = Knit.GetService("AbilityService")
        :ApplyBrace(target.Parent, attackerRoot and attackerRoot.Position or nil, amount)
    if dealer and dealer:IsA("Player") then
        Knit.GetService("StatsService"):OnDamage(dealer, target.Parent, math.min(amount, target.Health))
    end
    target:TakeDamage(amount)
end

function WeaponService:GiveLoadout(player)
    local backpack = player:FindFirstChildOfClass("Backpack")
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not backpack or not humanoid then
        return
    end
    backpack:ClearAllChildren()
    for _, child in character:GetChildren() do
        if child:IsA("Tool") then
            child:Destroy()
        end
    end

    local loadout = Knit.GetService("LoadoutService"):Get(player)
    local first
    for _, slot in { "Primary", "Secondary", "Melee", "Utility" } do
        local template = loadout[slot] and self.Tools:FindFirstChild(loadout[slot])
        if template then
            local tool = template:Clone()
            Knit.GetService("SkinService"):Apply(tool, player)
            tool.Parent = backpack
            first = first or tool
        end
    end
    if first then
        task.delay(0.1, function()
            if humanoid.Health > 0 and first.Parent == backpack then
                humanoid:EquipTool(first)
            end
        end)
    end
end

function WeaponService:KnitStart()
    self.Tools = ReplicatedStorage:WaitForChild("WeaponTools")

    -- Studio can drop Model.PrimaryPart while importing a generated .rbxm
    -- through Rojo. The kit uses it to align the muzzle and firing model.
    for _, folder in { self.Tools, ReplicatedStorage:WaitForChild("StudioWeaponTools") } do
        for _, tool in folder:GetChildren() do
            if tool:IsA("Tool") then
                for _, model in tool:GetChildren() do
                    if model:IsA("Model") and not model.PrimaryPart then
                        local attachment = model:FindFirstChild("HandleAttachment", true)
                        local body = attachment and attachment.Parent
                        if body and body:IsA("BasePart") then
                            model.PrimaryPart = body
                        end
                    end
                end
            end
        end
    end

    -- The kit's ServerWeaponsScript clones its folder into ReplicatedStorage on startup.
    local systemFolder = ReplicatedStorage:WaitForChild("WeaponsSystem", 30)
    if not systemFolder then
        warn("[WeaponService] WeaponsSystem folder never appeared; is the kit in ServerScriptService?")
        return
    end
    local WeaponsSystem = require(systemFolder.WeaponsSystem)
    WeaponsSystem.setGetTeamCallback(teamOf)
    WeaponsSystem.setDamageCallback(onDamage)

    local function watch(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.3) -- let the kit's client script and the character finish loading
            self:GiveLoadout(player)
        end)
        if player.Character then
            self:GiveLoadout(player)
        end
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return WeaponService
