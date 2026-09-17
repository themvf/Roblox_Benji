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

    local endPoints = {}
    for _ = 1, stats.Pellets do
        local spread = CFrame.Angles(
            math.rad((math.random() - 0.5) * stats.Spread),
            math.rad((math.random() - 0.5) * stats.Spread),
            0
        )
        local dir = (CFrame.lookAt(origin, origin + direction) * spread).LookVector
        local hit = workspace:Raycast(origin, dir * stats.Range, params)
        table.insert(endPoints, hit and hit.Position or origin + dir * stats.Range)
        if hit and hit.Instance then
            local model = hit.Instance:FindFirstAncestorOfClass("Model")
            local hum = model and model:FindFirstChildOfClass("Humanoid")
            local victim = model and Players:GetPlayerFromCharacter(model)
            if hum and hum.Health > 0 and victim and victim:GetAttribute("Team") ~= player:GetAttribute("Team") then
                local dmg = stats.Damage
                local headshot = hit.Instance.Name == "Head" and stats.HeadshotMultiplier ~= nil
                if headshot then
                    dmg *= stats.HeadshotMultiplier
                end
                hum:TakeDamage(dmg)
                self.Hit:Fire(player, dmg, headshot)
            end
        end
    end
    self.Tracer:FireExcept(player, player, origin, endPoints)
end

Players.PlayerRemoving:Connect(function(p)
    lastShot[p] = nil
end)

return WeaponService
