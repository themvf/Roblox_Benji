-- Melee weapons: the first weapon type outside the Weapons Kit.
-- Client asks to swing; server checks cooldown and the equipped tool, sweeps an arc
-- in front of the character, damages enemies once per swing, and plays the swing
-- (grip tween + slash arc) so everyone sees it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local MeleeService = Knit.CreateService({
    Name = "MeleeService",
    Client = {
        Swung = Knit.CreateSignal(), -- (character, weaponName) for client-side flourish later
    },
})

local lastSwing = {} -- [player] = os.clock()

local function sameTeam(a, b)
    local ta, tb = a:GetAttribute("Team"), b:GetAttribute("Team")
    return ta ~= nil and ta == tb
end

local function playSwing(tool, stats)
    -- Grip tween: raise, slash across, return. Replicates because the server owns the tool.
    local rest = tool.Grip
    local wind = rest * CFrame.Angles(math.rad(-70), 0, math.rad(20))
    local through = rest * CFrame.Angles(math.rad(60), 0, math.rad(-40))
    local t1 = TweenService:Create(
        tool,
        TweenInfo.new(stats.Cooldown * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Grip = wind }
    )
    local t2 = TweenService:Create(
        tool,
        TweenInfo.new(stats.Cooldown * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Grip = through }
    )
    local t3 = TweenService:Create(
        tool,
        TweenInfo.new(stats.Cooldown * 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Grip = rest }
    )
    t1:Play()
    t1.Completed:Once(function()
        t2:Play()
        t2.Completed:Once(function()
            t3:Play()
        end)
    end)
end

local function slashArc(root, stats)
    local arc = Instance.new("Part")
    arc.Name = "Slash"
    arc.Anchored = true
    arc.CanCollide = false
    arc.CanQuery = false
    arc.Material = Enum.Material.Neon
    arc.Color = Color3.fromRGB(200, 240, 255)
    arc.Transparency = 0.2
    arc.Size = Vector3.new(stats.Range * 1.6, 0.2, stats.Range * 0.5)
    arc.CFrame = root.CFrame * CFrame.new(0, 0.5, -stats.Range * 0.45) * CFrame.Angles(0, 0, math.rad(15))
    arc.Parent = workspace
    TweenService:Create(arc, TweenInfo.new(0.18), { Transparency = 1, Size = arc.Size * 1.2 }):Play()
    Debris:AddItem(arc, 0.2)
end

function MeleeService.Client:Swing(player, weaponName)
    local stats = Weapons[weaponName]
    if not stats or stats.Type ~= "Melee" then
        return false
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local tool = character and character:FindFirstChildOfClass("Tool")
    if not root or not humanoid or humanoid.Health <= 0 or not tool or tool.Name ~= weaponName then
        return false
    end

    local now = os.clock()
    if lastSwing[player] and now - lastSwing[player] < stats.Cooldown * 0.95 then
        return false
    end
    lastSwing[player] = now

    playSwing(tool, stats)
    slashArc(root, stats)
    self.Swung:FireAll(character, weaponName)

    -- Hit check on the swing's impact frame
    task.delay(stats.Cooldown * 0.3, function()
        if not root.Parent then
            return
        end
        local origin = root.Position
        local forward = root.CFrame.LookVector
        local halfArc = math.rad(stats.Arc / 2)
        for _, other in Players:GetPlayers() do
            if other ~= player and not sameTeam(player, other) then
                local oc = other.Character
                local oroot = oc and oc:FindFirstChild("HumanoidRootPart")
                local ohum = oc and oc:FindFirstChildOfClass("Humanoid")
                if oroot and ohum and ohum.Health > 0 then
                    local offset = oroot.Position - origin
                    local flat = Vector3.new(offset.X, 0, offset.Z)
                    if flat.Magnitude <= stats.Range + 2 and math.abs(offset.Y) < 8 then
                        local angle =
                            math.acos(math.clamp(flat.Unit:Dot(Vector3.new(forward.X, 0, forward.Z).Unit), -1, 1))
                        if angle <= halfArc then
                            oc:SetAttribute("LastHitBy", player.UserId)
                            Knit.GetService("StatsService"):OnDamage(player, oc, math.min(stats.Damage[1], ohum.Health))
                            ohum:TakeDamage(stats.Damage[1])
                        end
                    end
                end
            end
        end
    end)
    return true
end

Players.PlayerRemoving:Connect(function(p)
    lastSwing[p] = nil
end)

return MeleeService
