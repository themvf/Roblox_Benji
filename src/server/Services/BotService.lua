-- FPS Playtest Bot Specification v1, implemented.
-- Bots exist to validate Convergence, not to win. Spec sections referenced in comments:
-- S2 timing, S3 difficulty, S4 combat, S5 reload, S6/S7 objective + archetypes, S8 zone behaviour,
-- S9 target selection, S10 stuck, S11 respawn, S12 label, S13 composition, S14 telemetry.
-- Chat: /bots N (per team) · /botlevel easy|normal|hard|mix · /botdebug on|off · /botreport
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BotService = Knit.CreateService({ Name = "BotService" })

BotService.Bots = {}
BotService.Level = "Mix" -- S13: 4 Normal / 1 Easy / 1 Hard per team at 6v6
BotService.Debug = true
BotService.LastReport = nil

local TEAM_COLORS = { Red = Color3.fromRGB(255, 70, 70), Blue = Color3.fromRGB(70, 140, 255) }

-- ===== S2 global timing =====
local T = {
    Perception = 0.20,
    LongPath = 25,
    PathRefresh = 4.0,
    LosRecheck = 0.10,
    LosLostGrace = 0.6,
    ObjectiveEval = 0.50,
    EngageRange = 45,
    SightRange = 60,
    ShotInterval = 0.1,
    StuckWindow = 1.5,
    StuckDistance = 2,
    StuckFailCount = 3,
    StuckFailWindow = 10,
    AntiStack = 6,
    OrientDelay = 0.4,
    LeaveZoneEnemyRange = 18,
}

-- ===== S3 difficulty =====
local LEVELS = {
    Easy = {
        Speed = 15,
        Reaction = 0.55,
        Reacquire = 0.40,
        AimError = 7,
        Burst = { 2, 4 },
        BurstGap = 0.45,
        Mag = 20,
        Reload = 1.8,
        Range = { 18, 30 },
        RetreatHp = 0.45,
        RetreatFor = 3.5,
        SwitchCooldown = 1.75,
        MaxChase = 25,
        StaticReposition = 5.0,
        FlankOffset = 25,
        AnchorChase = 18,
        Hit = { { 10, 0.72 }, { 20, 0.62 }, { 35, 0.48 }, { 50, 0.32 }, { math.huge, 0.18 } },
    },
    Normal = {
        Speed = 16,
        Reaction = 0.32,
        Reacquire = 0.25,
        AimError = 4.5,
        Burst = { 3, 6 },
        BurstGap = 0.30,
        Mag = 20,
        Reload = 1.6,
        Range = { 20, 35 },
        RetreatHp = 0.35,
        RetreatFor = 3.0,
        SwitchCooldown = 1.25,
        MaxChase = 35,
        StaticReposition = 3.5,
        FlankOffset = 35,
        AnchorChase = 22,
        Hit = { { 10, 0.82 }, { 20, 0.74 }, { 35, 0.62 }, { 50, 0.48 }, { math.huge, 0.30 } },
    },
    Hard = {
        Speed = 18,
        Reaction = 0.20,
        Reacquire = 0.16,
        AimError = 2.5,
        Burst = { 4, 7 },
        BurstGap = 0.22,
        Mag = 20,
        Reload = 1.45,
        Range = { 22, 40 },
        RetreatHp = 0.25,
        RetreatFor = 2.5,
        SwitchCooldown = 0.90,
        MaxChase = 45,
        StaticReposition = 2.5,
        FlankOffset = 45,
        AnchorChase = 28,
        Hit = { { 10, 0.90 }, { 20, 0.84 }, { 35, 0.75 }, { 50, 0.62 }, { math.huge, 0.42 } },
    },
}

-- ===== S7 archetype multipliers =====
local ARCH = {
    Assault = { Attack = 1.5, Defend = 0.8, Flank = 0.7 },
    Anchor = { Attack = 0.6, Defend = 1.6, Flank = 0.5 },
    Flanker = { Attack = 1.2, Defend = 0.7, Flank = 1.6 },
}
local SHOT_DAMAGE = 12
local nextId = -1000

local function otherTeam(t)
    return t == "Red" and "Blue" or "Red"
end
local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end
local function now()
    return os.clock()
end

-- ===== S13 composition =====
local function composition(perTeam)
    local arch, lvl = {}, {}
    if perTeam >= 6 then
        arch = { "Assault", "Assault", "Anchor", "Anchor", "Flanker", "Flanker" }
        lvl = { "Normal", "Normal", "Normal", "Normal", "Easy", "Hard" }
    elseif perTeam >= 4 then
        arch = { "Assault", "Assault", "Anchor", "Flanker" }
    end
    local cycle = { "Assault", "Anchor", "Flanker" }
    for i = 1, perTeam do
        arch[i] = arch[i] or cycle[((i - 1) % 3) + 1]
        lvl[i] = lvl[i] or "Normal"
    end
    return arch, lvl
end

-- ===== rig =====
local function makeRig(bot)
    local desc = Instance.new("HumanoidDescription")
    local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    model.Name = bot.Name
    local hum = model:FindFirstChildOfClass("Humanoid")
    hum.DisplayName = bot.Name
    hum.WalkSpeed = bot.Level.Speed
    hum.AutoRotate = true
    hum.BreakJointsOnDeath = false
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") and (d.Name:find("Torso") or d.Name:find("Arm") or d.Name:find("Leg")) then
            d.Color = TEAM_COLORS[bot.Team]
        end
    end
    local hl = Instance.new("Highlight")
    hl.FillTransparency = 1
    hl.OutlineColor = TEAM_COLORS[bot.Team]
    hl.OutlineTransparency = 0.2
    hl.Parent = model
    model:SetAttribute("Team", bot.Team)
    model:SetAttribute("Bot", true)

    -- S4: weapon equipped (assault rifle mesh in the right hand)
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local tool = tools and tools:FindFirstChild("AssaultRifle")
    local src = tool and tool:FindFirstChildOfClass("Model")
    local hand = model:FindFirstChild("RightHand")
    bot.WeaponEquipped = false
    if src and hand then
        local gun = src:Clone()
        gun.Name = "BotWeapon"
        for _, d in gun:GetDescendants() do
            if d:IsA("BasePart") then
                d.Anchored = false
                d.CanCollide = false
                d.Massless = true
            elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
                d:Destroy()
            end
        end
        local root = gun.PrimaryPart or gun:FindFirstChildWhichIsA("BasePart")
        local handleAtt = root and root:FindFirstChild("HandleAttachment")
        local offset = handleAtt and handleAtt.CFrame:Inverse() or CFrame.new()
        local weld = Instance.new("Weld")
        weld.Part0 = hand
        weld.Part1 = root
        weld.C0 = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(-90), 0, 0) * offset
        weld.Parent = root
        gun.Parent = model
        bot.Muzzle = gun:FindFirstChild("TipAttachment", true)
        bot.WeaponEquipped = true
    end

    -- S12 debug label
    local bb = Instance.new("BillboardGui")
    bb.Name = "BotLabel"
    bb.Size = UDim2.fromOffset(220, 46)
    bb.StudsOffset = Vector3.new(0, 3.4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 160
    bb.Enabled = BotService.Debug
    bb.Parent = model:FindFirstChild("Head") or model
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = TEAM_COLORS[bot.Team]
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent = bb
    bot.Label = lbl
    return model, hum
end

-- ===== perception =====
local function enemiesOf(team)
    local out = {}
    for _, p in Players:GetPlayers() do
        if p:GetAttribute("InMatch") and p:GetAttribute("Team") == otherTeam(team) then
            local c = p.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                table.insert(out, { Character = c, Humanoid = h, Root = r, Name = p.Name })
            end
        end
    end
    for _, b in BotService.Bots do
        if b.Alive and b.Team == otherTeam(team) and b.Character.Parent and b.Root then
            table.insert(out, { Character = b.Character, Humanoid = b.Humanoid, Root = b.Root, Name = b.Name })
        end
    end
    return out
end

local function los(bot, target)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { bot.Character }
    local from = bot.Root.Position + Vector3.new(0, 1.5, 0)
    local hit = workspace:Raycast(from, target.Root.Position - from, params)
    return hit ~= nil and hit.Instance:IsDescendantOf(target.Character)
end

local function inZone(pos, z)
    return flat(z.Position - pos).Magnitude <= z.Radius
end

-- S9 target scoring
local function scoreTarget(bot, e, dist, zones)
    local s = 0
    for _, z in zones do
        if not z.Closed and inZone(e.Root.Position, z) then
            s += 50
            break
        end
    end
    if bot.Character:GetAttribute("LastHitByName") == e.Name then
        s += 40
    end
    if dist <= 20 then
        s += 30
    end
    if e.Character:GetAttribute("Bounty") then
        s += 20
    end
    if e.Humanoid.Health / e.Humanoid.MaxHealth < 0.35 then
        s += 10
    end
    if bot.Zone then
        local eFromZone = flat(e.Root.Position - bot.Zone.Position).Magnitude
        if eFromZone > bot.Zone.Radius * 2 then
            s -= 15
        end
        if eFromZone > bot.MaxChase then
            s -= 25
        end
    end
    return s - dist * 0.2
end

local function perceive(bot, zones)
    local t = now()
    local best, bestScore, bestD
    for _, e in enemiesOf(bot.Team) do
        local d = (e.Root.Position - bot.Root.Position).Magnitude
        if d <= T.SightRange and los(bot, e) then
            local s = scoreTarget(bot, e, d, zones)
            if not bestScore or s > bestScore then
                best, bestScore, bestD = e, s, d
            end
        end
    end
    -- S9 target switch cooldown
    if best and bot.Target and bot.Target.Character ~= best.Character then
        local cur = bot.Target
        if t - (bot.TargetSince or 0) < bot.Level.SwitchCooldown and cur.Humanoid.Health > 0 and los(bot, cur) then
            best = cur
            bestD = (cur.Root.Position - bot.Root.Position).Magnitude
        end
    end
    if best then
        if not bot.Target or bot.Target.Character ~= best.Character then
            bot.Target = best
            bot.TargetSince = t
            local reacquire = bot.LastTargetLost and (t - bot.LastTargetLost) < 4
            bot.FireAllowedAt = t + (reacquire and bot.Level.Reacquire or bot.Level.Reaction)
            if not bot.Telemetry.FirstContact and bot.SpawnedAt then
                bot.Telemetry.FirstContact = t - bot.SpawnedAt
            end
        end
        bot.TargetDist = bestD
        bot.LosLostAt = nil
    elseif bot.Target then
        bot.LosLostAt = bot.LosLostAt or t
        if t - bot.LosLostAt > T.LosLostGrace then
            bot.Target = nil
            bot.LastTargetLost = t
        end
    end
    bot.Allies = {}
    for _, b in BotService.Bots do
        if b ~= bot and b.Alive and b.Team == bot.Team and b.Root then
            table.insert(bot.Allies, b.Root.Position)
        end
    end
end

-- ===== S6/S7 objective choice =====
local function zoneScore(bot, z)
    local m = ARCH[bot.Archetype]
    local d = flat(z.Position - bot.Root.Position).Magnitude
    local mine = z.Owner == bot.Team
    local score
    if mine and z.Contested then
        score = 100 * math.max(m.Defend, m.Attack) -- S6 #1: contest an objective being lost
    elseif not mine then
        score = 80 * m.Attack + (z.Contested and 15 or 0)
        if bot.Archetype == "Flanker" then
            score += d * 0.1 -- distant enemy zone preferred
        end
    else
        score = 60 * m.Defend
    end
    return score - d * 0.35
end

local function chooseZone(bot, zones)
    local best, bestS
    for _, z in zones do
        if not z.Closed then
            local s = zoneScore(bot, z)
            if not bestS or s > bestS then
                best, bestS = z, s
            end
        end
    end
    return best
end

-- S8: a spot inside the radius, off centre, clear of allies
local function zoneSpot(bot, z)
    for _ = 1, 8 do
        local a = math.random() * math.pi * 2
        local r = z.Radius * (0.35 + math.random() * 0.5)
        local p = z.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
        local ok = true
        for _, ally in bot.Allies or {} do
            if flat(ally - p).Magnitude < T.AntiStack then
                ok = false
                break
            end
        end
        if ok then
            return p
        end
    end
    return z.Position
end

-- ===== decision =====
local function decide(bot, zones)
    local t = now()
    local hum = bot.Humanoid
    local hpFrac = hum.Health / hum.MaxHealth
    local prev = bot.State

    if bot.Reloading then
        bot.State = "Reload"
    elseif t < (bot.OrientUntil or 0) then
        bot.State = "SeekObjective"
    elseif not (bot.State == "Reposition" and t < (bot.RepositionUntil or 0)) then
        if t - (bot.ZoneEvalAt or 0) >= T.ObjectiveEval then
            bot.ZoneEvalAt = t
            local z = chooseZone(bot, zones)
            if z ~= bot.Zone then
                bot.Zone = z
                bot.ZoneSpot = z and zoneSpot(bot, z) or nil
                bot.Telemetry.Transitions += 1
            end
        end
        local atZone = bot.Zone and inZone(bot.Root.Position, bot.Zone)
        local enemyNear = bot.Target and bot.TargetDist <= 30

        if bot.Ammo <= 0 or (bot.Ammo < bot.Level.Mag * 0.25 and not enemyNear) then
            bot.Reloading = true -- S5
            bot.ReloadDone = t + bot.Level.Reload
            bot.State = "Reload"
        elseif hpFrac < bot.Level.RetreatHp and bot.Target and bot.Archetype ~= "Assault" then
            bot.State = "Reposition"
            bot.RepositionUntil = t + bot.Level.RetreatFor
        elseif bot.Target and bot.TargetDist <= T.EngageRange and t >= (bot.FireAllowedAt or 0) then
            local mustStay = atZone and bot.TargetDist > T.LeaveZoneEnemyRange and bot.Zone.Owner ~= bot.Team
            bot.State = "Engage"
            bot.HoldZoneWhileEngaging = mustStay or bot.Archetype == "Anchor"
        elseif atZone then
            bot.State = "Defend"
        else
            bot.State = "SeekObjective"
        end
    end

    if bot.State ~= prev then
        bot.StateSince = t
        if prev == "Engage" then
            bot.CombatStaticSince = nil
        end
    end
end

-- ===== navigation =====
local function computePath(bot, goal)
    bot.Telemetry.Repaths += 1
    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 6,
    })
    local ok = pcall(function()
        path:ComputeAsync(bot.Root.Position, goal)
    end)
    if ok and path.Status == Enum.PathStatus.Success then
        bot.Waypoints = path:GetWaypoints()
        bot.WaypointIndex = 2
        bot.PathGoal = goal
        bot.PathTime = now()
        if bot.BlockedConn then
            bot.BlockedConn:Disconnect()
        end
        bot.BlockedConn = path.Blocked:Connect(function(idx)
            if idx >= (bot.WaypointIndex or 1) then
                bot.PathGoal = nil
            end
        end)
        return true
    end
    bot.Waypoints, bot.PathGoal = nil, nil
    return false
end

local function flankPoint(bot, z)
    local approach = flat(z.Position - bot.Root.Position)
    if approach.Magnitude < 1 then
        return z.Position
    end
    local side = Vector3.new(-approach.Unit.Z, 0, approach.Unit.X) * (bot.FlankSide or 1) * bot.Level.FlankOffset
    return z.Position + side
end

local function navigateTo(bot, goal)
    local hum = bot.Humanoid
    bot.MoveRequested = true
    if flat(goal - bot.Root.Position).Magnitude <= T.LongPath then
        hum:MoveTo(goal)
        return
    end
    local stale = not bot.PathGoal or (bot.PathGoal - goal).Magnitude > 8 or now() - (bot.PathTime or 0) > T.PathRefresh
    if stale and not computePath(bot, goal) then
        hum:MoveTo(goal)
        return
    end
    local wps = bot.Waypoints
    local wp = wps and wps[bot.WaypointIndex or 2]
    if not wp then
        hum:MoveTo(goal)
        return
    end
    if wp.Action == Enum.PathWaypointAction.Jump then
        hum.Jump = true
    end
    hum:MoveTo(wp.Position)
    if flat(wp.Position - bot.Root.Position).Magnitude < 4 then
        bot.WaypointIndex = (bot.WaypointIndex or 2) + 1
    end
end

-- S10 stuck detection + recovery ladder
local function stuckCheck(bot)
    local t = now()
    if t - (bot.StuckAt or 0) < T.StuckWindow then
        return
    end
    local moved = bot.LastPos and (bot.Root.Position - bot.LastPos).Magnitude or 99
    bot.LastPos = bot.Root.Position
    bot.StuckAt = t
    local moving = bot.MoveRequested
        and (bot.State == "SeekObjective" or bot.State == "Reposition" or bot.State == "Reload")
    bot.MoveRequested = false
    if not moving or moved >= T.StuckDistance then
        bot.StuckStep = 0
        return
    end
    bot.Telemetry.StuckEvents += 1
    bot.StuckStep = (bot.StuckStep or 0) + 1
    local step = bot.StuckStep
    if step == 1 then
        bot.Humanoid.Jump = true
    elseif step == 2 then
        bot.Humanoid:MoveTo(bot.Zone and bot.Zone.Position or bot.Root.Position)
    elseif step == 3 then
        bot.PathGoal = nil
    elseif step == 4 then
        bot.FlankSide = -(bot.FlankSide or 1)
        bot.PathGoal = nil
    elseif step == 5 then
        bot.Humanoid:MoveTo(bot.Root.Position + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
    else
        bot.State = "SeekObjective"
        bot.PathGoal, bot.Waypoints = nil, nil
        bot.StuckStep = 0
    end
    bot.StuckTimes = bot.StuckTimes or {}
    table.insert(bot.StuckTimes, t)
    while bot.StuckTimes[1] and t - bot.StuckTimes[1] > T.StuckFailWindow do
        table.remove(bot.StuckTimes, 1)
    end
    if #bot.StuckTimes > T.StuckFailCount then
        bot.Telemetry.PathingFailures += 1
        bot.StuckTimes = {}
        local p = bot.Root.Position
        warn(("[Bots] PATHING_FAILURE %s at (%.0f, %.0f, %.0f) state=%s"):format(bot.Name, p.X, p.Y, p.Z, bot.State))
    end
end

-- ===== S4 combat =====
local function tracer(from, to, color)
    local d = (to - from).Magnitude
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Size = Vector3.new(0.06, 0.06, d)
    p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -d / 2)
    p.Parent = workspace
    Debris:AddItem(p, 0.06)
end

local function hitChance(bot, dist)
    for _, band in bot.Level.Hit do
        if dist <= band[1] then
            return band[2]
        end
    end
    return 0.2
end

local function fire(bot)
    local target = bot.Target
    local t = now()
    if not target or bot.Ammo <= 0 or not bot.WeaponEquipped or target.Humanoid.Health <= 0 then
        return
    end
    if t < (bot.FireAllowedAt or 0) then
        return
    end
    if t - (bot.LosCheckAt or 0) >= T.LosRecheck then
        bot.LosCheckAt = t
        bot.HasLos = los(bot, target)
    end
    if not bot.HasLos then
        return
    end
    if bot.BurstLeft <= 0 then
        if t < (bot.NextBurst or 0) then
            return
        end
        bot.BurstLeft = math.random(bot.Level.Burst[1], bot.Level.Burst[2])
    end
    if t - (bot.LastShot or 0) < T.ShotInterval then
        return
    end
    bot.LastShot = t
    bot.BurstLeft -= 1
    bot.Ammo -= 1
    bot.Telemetry.Shots += 1
    if bot.BurstLeft <= 0 then
        bot.NextBurst = t + bot.Level.BurstGap + (math.random() - 0.5) * 0.1
    end

    local from = bot.Muzzle and bot.Muzzle.WorldPosition or (bot.Root.Position + Vector3.new(0.6, 1.2, 0))
    local aimAt = target.Root.Position + Vector3.new(0, 0.5, 0)
    local err = math.rad(bot.Level.AimError)
    local dir = (aimAt - from).Unit
    local jitter = CFrame.Angles((math.random() - 0.5) * 2 * err, (math.random() - 0.5) * 2 * err, 0)
    local shotDir = (CFrame.lookAt(from, from + dir) * jitter).LookVector
    tracer(from, from + shotDir * bot.TargetDist, TEAM_COLORS[bot.Team])
    bot.Telemetry.CombatDistSum += bot.TargetDist
    bot.Telemetry.CombatSamples += 1

    if math.random() < hitChance(bot, bot.TargetDist) then
        bot.Telemetry.Hits += 1
        target.Character:SetAttribute("LastHitBy", bot.Id)
        target.Character:SetAttribute("LastHitByName", bot.Name)
        local dmg = Knit.GetService("AbilityService"):ApplyBrace(target.Character, bot.Root.Position, SHOT_DAMAGE)
        target.Humanoid:TakeDamage(dmg)
    end
end

local function strafe(bot)
    local t = now()
    if t > (bot.StrafeUntil or 0) then
        bot.StrafeDir = (math.random() < 0.5) and -1 or 1
        bot.StrafeUntil = t + 1.0 + math.random()
    end
    local toTarget = flat(bot.Target.Root.Position - bot.Root.Position)
    if toTarget.Magnitude < 1 then
        return
    end
    local side = Vector3.new(-toTarget.Unit.Z, 0, toTarget.Unit.X) * bot.StrafeDir * (5 + math.random() * 3)
    local push = Vector3.zero
    local lo, hi = bot.Level.Range[1], bot.Level.Range[2]
    if bot.TargetDist > hi then
        push = toTarget.Unit * 6
    elseif bot.TargetDist < lo then
        push = -toTarget.Unit * 6
    end
    bot.MoveRequested = true
    bot.Humanoid:MoveTo(bot.Root.Position + side + push + (bot.RepositionNudge or Vector3.zero))
    bot.RepositionNudge = nil
end

local function faceTarget(bot)
    local tp = bot.Target.Root.Position
    bot.Humanoid.AutoRotate = false
    bot.Root.CFrame = CFrame.lookAt(bot.Root.Position, Vector3.new(tp.X, bot.Root.Position.Y, tp.Z))
end

-- ===== act (every frame) =====
local function act(bot, dt)
    local hum = bot.Humanoid
    local state = bot.State
    local tm = bot.Telemetry
    tm.StateTime[state] = (tm.StateTime[state] or 0) + dt
    if bot.Zone and inZone(bot.Root.Position, bot.Zone) then
        if bot.Zone.Owner == bot.Team then
            tm.DefendSeconds += dt
        else
            tm.CaptureSeconds += dt
        end
        if not tm.FirstObjective and bot.SpawnedAt then
            tm.FirstObjective = now() - bot.SpawnedAt
        end
    end
    if bot.LastPos2 then
        tm.Distance += (bot.Root.Position - bot.LastPos2).Magnitude
    end
    bot.LastPos2 = bot.Root.Position

    if state == "Reload" then
        hum.AutoRotate = true
        if now() >= (bot.ReloadDone or 0) then
            bot.Ammo = bot.Level.Mag
            bot.Reloading = false
        elseif bot.Zone and not inZone(bot.Root.Position, bot.Zone) then
            navigateTo(bot, bot.ZoneSpot or bot.Zone.Position)
        end
    elseif state == "Engage" then
        faceTarget(bot)
        fire(bot)
        bot.CombatStaticSince = bot.CombatStaticSince or now()
        if now() - bot.CombatStaticSince > bot.Level.StaticReposition then
            bot.CombatStaticSince = now()
            bot.StrafeUntil = 0
            bot.RepositionNudge = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
        end
        local farFromZone = bot.Zone and flat(bot.Zone.Position - bot.Root.Position).Magnitude > bot.Zone.Radius * 2
        local pushToZone = (bot.Archetype == "Assault" and farFromZone and bot.Zone.Owner ~= bot.Team)
            or (bot.HoldZoneWhileEngaging and bot.Zone and not inZone(bot.Root.Position, bot.Zone))
        if pushToZone then
            navigateTo(bot, bot.ZoneSpot or bot.Zone.Position) -- keep the objective while shooting
        else
            strafe(bot)
        end
    elseif state == "Reposition" then
        hum.AutoRotate = true
        local away
        if bot.Target then
            away = -flat(bot.Target.Root.Position - bot.Root.Position).Unit
        else
            away = Vector3.new(bot.Team == "Red" and -1 or 1, 0, 0)
        end
        local goal = bot.Root.Position + away * 18
        if bot.Archetype == "Anchor" and bot.Zone and bot.Zone.Owner == bot.Team then
            goal = bot.Zone.Position
        end
        navigateTo(bot, goal)
    elseif state == "Defend" then
        hum.AutoRotate = true
        if now() - (bot.DefendMoveAt or 0) > 2.5 then
            bot.DefendMoveAt = now()
            bot.ZoneSpot = zoneSpot(bot, bot.Zone)
            bot.MoveRequested = true
            hum:MoveTo(bot.ZoneSpot)
        end
    else
        hum.AutoRotate = true
        if bot.Zone then
            local goal = bot.ZoneSpot or bot.Zone.Position
            if bot.Archetype == "Flanker" and flat(goal - bot.Root.Position).Magnitude > 50 then
                goal = flankPoint(bot, bot.Zone)
                if not bot.FlankCounted then
                    bot.FlankCounted = true
                    tm.FlankUses += 1
                end
            else
                bot.FlankCounted = false
            end
            navigateTo(bot, goal)
        end
    end

    if bot.Label then
        local line2 = bot.Target and ("Enemy: " .. bot.Target.Name)
            or (bot.Zone and ("Target: " .. bot.Zone.Name) or "")
        bot.Label.Text = ("%s | %s | HP:%d | Ammo:%d\n%s"):format(bot.Archetype, state, hum.Health, bot.Ammo, line2)
    end
end

-- ===== lifecycle =====
local function newTelemetry()
    return {
        Distance = 0,
        Alive = 0,
        Kills = 0,
        Deaths = 0,
        Shots = 0,
        Hits = 0,
        CaptureSeconds = 0,
        DefendSeconds = 0,
        Transitions = 0,
        Repaths = 0,
        StuckEvents = 0,
        PathingFailures = 0,
        FlankUses = 0,
        CombatDistSum = 0,
        CombatSamples = 0,
        StateTime = {},
        Contacts = {},
        Objectives = {},
    }
end

function BotService:SpawnBot(bot, spawnCF)
    local model, hum = makeRig(bot)
    model:PivotTo(spawnCF + Vector3.new(0, 3, 0))
    model.Parent = workspace
    bot.Character, bot.Humanoid, bot.Root = model, hum, model:WaitForChild("HumanoidRootPart")
    bot.Alive = true
    bot.SpawnedAt = now()
    bot.OrientUntil = now() + T.OrientDelay -- S11
    bot.State = "SeekObjective"
    bot.StateSince = now()
    bot.Ammo, bot.BurstLeft, bot.Reloading = bot.Level.Mag, 0, false
    bot.Target, bot.Zone, bot.ZoneSpot, bot.Waypoints, bot.PathGoal = nil, nil, nil, nil, nil
    bot.FlankSide = (math.random() < 0.5) and -1 or 1
    bot.LastPos, bot.LastPos2, bot.StuckStep = nil, nil, 0
    bot.Telemetry.FirstContact, bot.Telemetry.FirstObjective = nil, nil
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            pcall(function()
                d:SetNetworkOwner(nil)
            end)
        end
    end
    hum.Died:Connect(function()
        bot.Alive = false
        local tm = bot.Telemetry
        tm.Deaths += 1
        tm.Alive += now() - bot.SpawnedAt
        if tm.FirstContact then
            table.insert(tm.Contacts, tm.FirstContact)
        end
        if tm.FirstObjective then
            table.insert(tm.Objectives, tm.FirstObjective)
        end
        if bot.BlockedConn then
            bot.BlockedConn:Disconnect()
        end
        local killerId = model:GetAttribute("LastHitBy")
        for _, b in self.Bots do
            if b.Id == killerId then
                b.Telemetry.Kills += 1
            end
        end
        local conv = Knit.GetService("ConvergenceService")
        if conv.CreditKill then
            conv:CreditKill(killerId, bot.Team)
        end
        if bot.Root and self.Match then
            local p = bot.Root.Position
            table.insert(self.Match.Deaths, { math.floor(p.X), math.floor(p.Y), math.floor(p.Z) })
        end
        task.delay(3, function()
            model:Destroy()
        end)
        task.delay(self.RespawnSeconds or 3.5, function()
            if self.Active then
                self:SpawnBot(bot, self:SpawnFor(bot.Team))
            end
        end)
    end)
end

function BotService:SpawnFor(team)
    local MapService = Knit.GetService("MapService")
    local points = MapService.Spawns and MapService.Spawns[team] or {}
    local p = points[math.random(#points)] or Vector3.new(0, 20, 0)
    return CFrame.new(p)
end

function BotService:Start(perTeam, respawnSeconds, getZones)
    self:Stop()
    self.Active = true
    self.RespawnSeconds = respawnSeconds
    self.Match = { StartedAt = now(), Deaths = {} }
    local archs, lvls = composition(perTeam)
    for _, team in { "Red", "Blue" } do
        for i = 1, perTeam do
            nextId -= 1
            local levelName = LEVELS[self.Level] and self.Level or lvls[i]
            local level = LEVELS[levelName]
            local bot = {
                Name = ("%s Bot %d"):format(team, i),
                Team = team,
                Id = nextId,
                Alive = false,
                LevelName = levelName,
                Level = level,
                Archetype = archs[i],
                MaxChase = archs[i] == "Anchor" and level.AnchorChase or level.MaxChase,
                Telemetry = newTelemetry(),
            }
            table.insert(self.Bots, bot)
            self:SpawnBot(bot, self:SpawnFor(team))
        end
    end

    local acc = 0
    self.Conn = RunService.Heartbeat:Connect(function(dt)
        if not self.Active then
            return
        end
        acc += dt
        local slow = acc >= T.Perception
        if slow then
            acc = 0
        end
        local zones = getZones()
        for _, bot in self.Bots do
            if bot.Alive and bot.Character.Parent and bot.Root and bot.Root.Parent then
                local ok, err = pcall(function()
                    if slow then
                        perceive(bot, zones)
                        decide(bot, zones)
                        stuckCheck(bot)
                    end
                    act(bot, dt)
                end)
                if not ok then
                    warn("[Bots] " .. tostring(err))
                end
            end
        end
    end)
end

-- S14 telemetry report, printed and kept on LastReport
function BotService:Report()
    local function avg(list)
        if #list == 0 then
            return nil
        end
        local s = 0
        for _, v in list do
            s += v
        end
        return s / #list
    end
    local lines = { "=== BOT REPORT ===" }
    local contacts, objectives = {}, {}
    local totalStuck, totalFail, totalShots, totalHits = 0, 0, 0, 0
    for _, b in self.Bots do
        local tm = b.Telemetry
        local alive = tm.Alive + ((b.Alive and b.SpawnedAt) and (now() - b.SpawnedAt) or 0)
        local cs = table.clone(tm.Contacts)
        local os_ = table.clone(tm.Objectives)
        if b.Alive and tm.FirstContact then
            table.insert(cs, tm.FirstContact)
        end
        if b.Alive and tm.FirstObjective then
            table.insert(os_, tm.FirstObjective)
        end
        for _, v in cs do
            table.insert(contacts, v)
        end
        for _, v in os_ do
            table.insert(objectives, v)
        end
        totalStuck += tm.StuckEvents
        totalFail += tm.PathingFailures
        totalShots += tm.Shots
        totalHits += tm.Hits
        local acc = tm.Shots > 0 and (tm.Hits / tm.Shots * 100) or 0
        local combatD = tm.CombatSamples > 0 and (tm.CombatDistSum / tm.CombatSamples) or 0
        local st = {}
        for k, v in tm.StateTime do
            table.insert(st, ("%s %.0fs"):format(k, v))
        end
        table.sort(st)
        table.insert(
            lines,
            ("%-12s %-7s %-6s alive %.0fs K%d D%d shots %d acc %.0f%% dist %.0f cap %.0fs def %.0fs repath %d stuck %d fail %d flank %d cdist %.0f | %s"):format(
                b.Name,
                b.Archetype,
                b.LevelName,
                alive,
                tm.Kills,
                tm.Deaths,
                tm.Shots,
                acc,
                tm.Distance,
                tm.CaptureSeconds,
                tm.DefendSeconds,
                tm.Repaths,
                tm.StuckEvents,
                tm.PathingFailures,
                tm.FlankUses,
                combatD,
                table.concat(st, ", ")
            )
        )
    end
    local dur = self.Match and (now() - self.Match.StartedAt) or 0
    local c, o = avg(contacts), avg(objectives)
    table.insert(
        lines,
        ("match %.0fs | spawn->contact avg %s (target 8-15s) | spawn->objective avg %s (target 10-18s) | overall acc %.0f%% (target 35-55) | stuck %d fail %d (target <1 fail per bot) | deaths logged %d"):format(
            dur,
            c and ("%.1fs"):format(c) or "n/a",
            o and ("%.1fs"):format(o) or "n/a",
            totalShots > 0 and totalHits / totalShots * 100 or 0,
            totalStuck,
            totalFail,
            self.Match and #self.Match.Deaths or 0
        )
    )
    local report = table.concat(lines, "\n")
    self.LastReport = report
    print(report)
    return report
end

function BotService:Stop()
    if self.Active and #self.Bots > 0 then
        self:Report()
    end
    self.Active = false
    if self.Conn then
        self.Conn:Disconnect()
        self.Conn = nil
    end
    for _, b in self.Bots do
        if b.BlockedConn then
            b.BlockedConn:Disconnect()
        end
        if b.Character then
            b.Character:Destroy()
        end
    end
    self.Bots = {}
end

function BotService:CountInZone(zone)
    local counts = { Red = 0, Blue = 0 }
    for _, b in self.Bots do
        if b.Alive and b.Character.Parent and b.Root then
            local d = b.Root.Position - zone.Position
            if flat(d).Magnitude <= zone.Radius and math.abs(d.Y) <= 12 then
                counts[b.Team] += 1
            end
        end
    end
    return counts
end

function BotService:KnitStart()
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    local function watch(player)
        player.Chatted:Connect(function(msg)
            local n = msg:match("^/bots%s+(%d+)")
            if n and tuning then
                tuning:SetAttribute("Convergence_BotsPerTeam", tonumber(n))
            end
            local lvl = msg:match("^/botlevel%s+(%a+)")
            if lvl then
                local name = lvl:sub(1, 1):upper() .. lvl:sub(2):lower()
                if LEVELS[name] or name == "Mix" then
                    self.Level = name
                end
            end
            local dbg = msg:match("^/botdebug%s+(%a+)")
            if dbg then
                self.Debug = dbg:lower() == "on"
                for _, b in self.Bots do
                    local bb = b.Character and b.Character:FindFirstChild("BotLabel", true)
                    if bb then
                        bb.Enabled = self.Debug
                    end
                end
            end
            if msg:lower():sub(1, 10) == "/botreport" then
                self:Report()
            end
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return BotService
