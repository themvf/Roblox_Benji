-- AbilityService: validation, damage, knockback, cooldowns, replication for mutant abilities.
-- Server decides everything; clients only request and render. Player victims are client-owned,
-- so knockback for players is sent as a signal they apply locally (like launch pads); bots and
-- other server-owned rigs get velocity directly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)

local AbilityService = Knit.CreateService({
    Name = "AbilityService",
    Client = {
        Knockback = Knit.CreateSignal(), -- (velocity) to a player victim
        Charge = Knit.CreateSignal(), -- (speed, duration, steerDegPerSec) to the charging player
        Cooldowns = Knit.CreateSignal(), -- ({ [name] = endsAtServerTime })
        Effect = Knit.CreateSignal(), -- (kind, position, radius) cosmetic, to everyone
    },
})

local cooldowns = {} -- [player] = { [ability] = endsAt (os.clock) }
local braces = {} -- [player] = { Until, BaseSpeed }
local charges = {} -- [player] = { Until, Hit = {} }
local telemetry = {} -- [player] = { Uses = {}, Hits = {} }

local function now()
    return os.clock()
end

local function tele(player)
    telemetry[player] = telemetry[player] or { Uses = {}, Hits = {} }
    return telemetry[player]
end

local function serverEnds(secondsFromNow)
    return workspace:GetServerTimeNow() + secondsFromNow
end

local function mutatedEgo(player)
    local mutation = Knit.GetService("MutationService"):State(player)
    if not mutation or not mutation.IsMutated then
        return nil
    end
    return AlterEgos.get(mutation.AlterEgoId)
end

-- enemies (players + bots) near a point
local function enemiesNear(player, position, radius)
    local myTeam = player:GetAttribute("Team")
    local out = {}
    for _, p in Players:GetPlayers() do
        if p ~= player and p:GetAttribute("InMatch") and p:GetAttribute("Team") ~= myTeam then
            local c = p.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 and (r.Position - position).Magnitude <= radius then
                table.insert(out, { Player = p, Character = c, Root = r, Humanoid = h })
            end
        end
    end
    for _, b in Knit.GetService("BotService").Bots do
        if b.Alive and b.Team ~= myTeam and b.Root and (b.Root.Position - position).Magnitude <= radius then
            table.insert(out, { Bot = b, Character = b.Character, Root = b.Root, Humanoid = b.Humanoid })
        end
    end
    return out
end

local function hurt(attacker, victim, amount)
    victim.Character:SetAttribute("LastHitBy", attacker.UserId)
    victim.Character:SetAttribute("LastHitByName", attacker.Name)
    local dealt = math.min(amount, victim.Humanoid.Health)
    Knit.GetService("StatsService"):OnDamage(attacker, victim.Character, dealt)
    victim.Humanoid:TakeDamage(amount)
end

local function shove(victim, velocity)
    if victim.Player then
        AbilityService.Client.Knockback:Fire(victim.Player, velocity)
    else
        victim.Root.AssemblyLinearVelocity = velocity
    end
end

local function sendCooldowns(player)
    local cd = cooldowns[player] or {}
    local out = {}
    for name, endsAt in cd do
        out[name] = serverEnds(math.max(0, endsAt - now()))
    end
    AbilityService.Client.Cooldowns:Fire(player, out)
end

-- ===== abilities =====
local function groundSlam(player, ego, def)
    local root = player.Character.HumanoidRootPart
    local origin = root.Position
    AbilityService.Client.Effect:FireAll("Slam", origin, def.Radius)
    -- shockwave ring
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.Material = Enum.Material.Neon
    ring.Color = ego.Color
    ring.Transparency = 0.3
    ring.Size = Vector3.new(0.4, 2, 2)
    ring.CFrame = CFrame.new(origin - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = workspace
    TweenService:Create(
        ring,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad),
        { Size = Vector3.new(0.4, def.Radius * 2, def.Radius * 2), Transparency = 1 }
    ):Play()
    Debris:AddItem(ring, 0.4)
    local hits = 0
    for _, v in enemiesNear(player, origin, def.Radius) do
        hits += 1
        hurt(player, v, def.Damage)
        local away = (v.Root.Position - origin)
        away = Vector3.new(away.X, 0, away.Z)
        away = away.Magnitude > 0.5 and away.Unit or root.CFrame.LookVector
        shove(v, away * def.Knockback + Vector3.new(0, def.Lift, 0))
    end
    return hits
end

local function brace(player, _ego, def)
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    local base = hum.WalkSpeed
    braces[player] = { Until = now() + def.Duration, BaseSpeed = base }
    hum.WalkSpeed = base * def.MoveSpeedMultiplier
    player.Character:SetAttribute("Bracing", true)
    task.delay(def.Duration, function()
        if braces[player] and hum.Parent then
            hum.WalkSpeed = braces[player].BaseSpeed
        end
        braces[player] = nil
        if player.Character then
            player.Character:SetAttribute("Bracing", nil)
        end
    end)
    return 0
end

local function charge(player, _ego, def)
    charges[player] = { Until = now() + def.Duration, Hit = {} }
    AbilityService.Client.Charge:Fire(player, def.Speed, def.Duration, def.SteerDegreesPerSecond)
    player.Character:SetAttribute("Charging", true)
    task.delay(def.Duration + 0.1, function()
        charges[player] = nil
        if player.Character then
            player.Character:SetAttribute("Charging", nil)
        end
    end)
    return 0
end

local HANDLERS = { GroundSlam = groundSlam, Brace = brace, Charge = charge }

function AbilityService.Client:Use(player, abilityName)
    local ego = mutatedEgo(player)
    if not ego then
        return false, "not mutated"
    end
    local def = ego.Abilities[abilityName]
    if not def then
        return false, "unknown ability"
    end
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or not character:FindFirstChild("HumanoidRootPart") then
        return false, "invalid state"
    end
    cooldowns[player] = cooldowns[player] or {}
    if (cooldowns[player][abilityName] or 0) > now() then
        return false, "cooldown"
    end
    cooldowns[player][abilityName] = now() + def.Cooldown
    local t = tele(player)
    t.Uses[abilityName] = (t.Uses[abilityName] or 0) + 1
    local hits = HANDLERS[abilityName](player, ego, def)
    if hits and hits > 0 then
        t.Hits[abilityName] = (t.Hits[abilityName] or 0) + 1
    end
    sendCooldowns(player)
    return true
end

-- Brace: called by damage sources. Returns the reduced amount.
function AbilityService:ApplyBrace(victimCharacter, attackerPosition, amount)
    local victim = Players:GetPlayerFromCharacter(victimCharacter)
    local b = victim and braces[victim]
    if not b or b.Until < now() then
        return amount
    end
    local ego = mutatedEgo(victim)
    local def = ego and ego.Abilities.Brace
    local root = victimCharacter:FindFirstChild("HumanoidRootPart")
    if not def or not root or not attackerPosition then
        return amount
    end
    local toAttacker = attackerPosition - root.Position
    toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
    if toAttacker.Magnitude < 0.5 then
        return amount
    end
    if root.CFrame.LookVector:Dot(toAttacker.Unit) >= def.FrontDot then
        return amount * (1 - def.FrontalResistance)
    end
    return amount
end

-- Charge hits: server sweeps in front of charging players every heartbeat
function AbilityService:KnitStart()
    game:GetService("RunService").Heartbeat:Connect(function()
        for player, c in charges do
            local ego = mutatedEgo(player)
            local def = ego and ego.Abilities.Charge
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if def and root and c.Until > now() then
                local front = root.Position + root.CFrame.LookVector * 3
                for _, v in enemiesNear(player, front, def.HitRadius) do
                    if not c.Hit[v.Character] then
                        c.Hit[v.Character] = true
                        hurt(player, v, def.Damage)
                        shove(v, root.CFrame.LookVector * def.Push + Vector3.new(0, 15, 0))
                        local t = tele(player)
                        t.Hits.Charge = (t.Hits.Charge or 0) + 1
                    end
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(p)
        cooldowns[p], braces[p], charges[p], telemetry[p] = nil, nil, nil, nil
    end)
end

function AbilityService:OnMutate(player, _ego)
    cooldowns[player] = {}
    sendCooldowns(player)
end

function AbilityService:OnRevert(player)
    local b = braces[player]
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if b and hum then
        hum.WalkSpeed = b.BaseSpeed
    end
    braces[player], charges[player] = nil, nil
    if player.Character then
        player.Character:SetAttribute("Bracing", nil)
        player.Character:SetAttribute("Charging", nil)
    end
end

function AbilityService:TelemetryFor(player)
    local t = telemetry[player]
    if not t then
        return "none"
    end
    local parts = {}
    for _, name in AlterEgos.ABILITY_ORDER do
        local uses = t.Uses[name] or 0
        local hits = t.Hits[name] or 0
        table.insert(parts, ("%s %d uses/%d hits"):format(name, uses, hits))
    end
    return table.concat(parts, ", ")
end

function AbilityService:ResetTelemetry()
    telemetry = {}
end

return AbilityService
