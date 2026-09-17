-- Server-authoritative hit validation. The client says "I shot from here in
-- this direction"; the server checks fire rate, position, and raycasts itself
-- before dealing damage. Never trust the client for damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local WeaponService = Knit.CreateService({
    Name = "WeaponService",
    Client = {
        Tracer = Knit.CreateSignal(), -- (shooter, origin, endPoints: {Vector3})
        Hit = Knit.CreateSignal(), -- (damage, headshot) sent to the shooter only
    },
})

local lastShot = {} -- [player] = os.clock()

-- Minimum gap between shots the server will accept. Burst weapons fire
-- several shots quickly, so use the burst delay for those.
local function minGap(stats)
    if stats.Burst then
        return stats.BurstDelay * 0.8
    end
    return stats.Cooldown * 0.9
end

function WeaponService.Client:Fire(player, weaponName, origin, direction)
    local stats = Weapons[weaponName]
    if not stats then
        return
    end
    if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
        return
    end

    local now = os.clock()
    if lastShot[player] and now - lastShot[player] < minGap(stats) then
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

    local maxRange = 1000
    local endPoints = {}
    local totalDamage, anyHeadshot = 0, false
    for _ = 1, stats.Pellets do
        local spread = CFrame.Angles(
            math.rad((math.random() - 0.5) * stats.Spread),
            math.rad((math.random() - 0.5) * stats.Spread),
            0
        )
        local dir = (CFrame.lookAt(origin, origin + direction) * spread).LookVector
        local hit = workspace:Raycast(origin, dir * maxRange, params)
        table.insert(endPoints, hit and hit.Position or origin + dir * maxRange)
        if hit and hit.Instance then
            local model = hit.Instance:FindFirstAncestorOfClass("Model")
            local hum = model and model:FindFirstChildOfClass("Humanoid")
            local victim = model and Players:GetPlayerFromCharacter(model)
            if hum and hum.Health > 0 and victim and victim:GetAttribute("Team") ~= player:GetAttribute("Team") then
                local headshot = hit.Instance.Name == "Head"
                local dmg = Weapons.DamageAt(stats, hit.Distance, headshot)
                hum:TakeDamage(dmg)
                totalDamage += dmg
                anyHeadshot = anyHeadshot or headshot
            end
        end
    end
    if totalDamage > 0 then
        self.Hit:Fire(player, math.round(totalDamage * 10) / 10, anyHeadshot)
    end
    self.Tracer:FireExcept(player, player, origin, endPoints)
end

Players.PlayerRemoving:Connect(function(p)
    lastShot[p] = nil
end)

return WeaponService
