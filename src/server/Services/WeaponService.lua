-- Server-authoritative hit validation. The client says "I shot from here in
-- this direction"; the server checks fire rate, position, and raycasts itself
-- before dealing damage. Never trust the client for damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local WeaponService = Knit.CreateService({
    Name = "WeaponService",
    Client = {},
})

local lastShot = {} -- [player] = os.clock()

function WeaponService.Client:Fire(player, weaponName, origin, direction)
    local stats = Weapons[weaponName]
    if not stats then
        return
    end
    if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
        return
    end

    local now = os.clock()
    if lastShot[player] and now - lastShot[player] < stats.FireRate * 0.9 then
        return -- firing too fast
    end
    lastShot[player] = now

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or (root.Position - origin).Magnitude > 10 then
        return
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }

    for _ = 1, stats.Pellets do
        local spread = CFrame.Angles(
            math.rad((math.random() - 0.5) * stats.Spread),
            math.rad((math.random() - 0.5) * stats.Spread),
            0
        )
        local dir = (CFrame.lookAt(origin, origin + direction) * spread).LookVector
        local hit = workspace:Raycast(origin, dir * stats.Range, params)
        if hit and hit.Instance then
            local model = hit.Instance:FindFirstAncestorOfClass("Model")
            local hum = model and model:FindFirstChildOfClass("Humanoid")
            local victim = model and Players:GetPlayerFromCharacter(model)
            if hum and victim and victim:GetAttribute("Team") ~= player:GetAttribute("Team") then
                local dmg = stats.Damage
                if hit.Instance.Name == "Head" and stats.HeadshotMultiplier then
                    dmg *= stats.HeadshotMultiplier
                end
                hum:TakeDamage(dmg)
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(p)
    lastShot[p] = nil
end)

return WeaponService
