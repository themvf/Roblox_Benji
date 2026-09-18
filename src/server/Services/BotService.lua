-- FPS playtest bots for Convergence. Built to behave like competent human playtesters, not to be smart.
--
--   Perception   visible enemies (LOS raycast), distance, threat, current zone state
--   Decision     state machine: SeekObjective | Defend | Engage | Reposition | Reload
--                objective behaviour outranks kill chasing; archetype sets the bias
--   Navigation   PathfindingService for long travel (recomputed on block / every few seconds),
--                direct MoveTo inside ~25 studs, jump on waypoints, stuck detection -> jump + repath.
--                Never waits on MoveToFinished; every tick re-evaluates.
--   Combat       weapon model in hand, reaction time, angular aim error, controlled bursts, reload, strafing
--   Personality  Easy / Normal / Hard (reaction, aim error, burst size, aggression) and
--                archetype Assault / Anchor / Flanker
--
-- Enable: chat "/bots N" (per team), difficulty "/botlevel easy|normal|hard", labels "/botdebug on|off".
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BotService = Knit.CreateService({ Name = "BotService" })

BotService.Bots = {}
BotService.Level = "Normal"
BotService.Debug = true

local TEAM_COLORS = { Red = Color3.fromRGB(255, 70, 70), Blue = Color3.fromRGB(70, 140, 255) }

-- ===== personality =====
local LEVELS = {
    Easy = {
        Reaction = 0.6,
        AimError = 9,
        Accuracy = 0.45,
        Burst = { 3, 4 },
        BurstGap = { 0.7, 1.1 },
        Speed = 15,
        Aggression = 0.4,
    },
    Normal = {
        Reaction = 0.35,
        AimError = 5,
        Accuracy = 0.6,
        Burst = { 3, 6 },
        BurstGap = { 0.45, 0.9 },
        Speed = 16,
        Aggression = 0.6,
    },
    Hard = {
        Reaction = 0.2,
        AimError = 2.5,
        Accuracy = 0.75,
        Burst = { 4, 6 },
        BurstGap = { 0.3, 0.6 },
        Speed = 18,
        Aggression = 0.8,
    },
}
local ARCHETYPES = { "Assault", "Anchor", "Flanker" }

local SHOT_DAMAGE = 12 -- assault-rifle class
local SHOT_INTERVAL = 0.1
local MAG = 20
local RELOAD_TIME = 1.6
local SIGHT = 60
local ENGAGE_RANGE = 45
local DIRECT_MOVE_RANGE = 25
local LOW_HEALTH = 0.35
local nextId = -1000

local function otherTeam(t)
    return t == "Red" and "Blue" or "Red"
end

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
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

    -- weapon in hand: the kit's assault rifle mesh, welded to the right hand (visual only)
    local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
    local tool = tools and tools:FindFirstChild("AssaultRifle")
    local src = tool and tool:FindFirstChildOfClass("Model")
    local hand = model:FindFirstChild("RightHand")
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
    end

    -- debug label
    local bb = Instance.new("BillboardGui")
    bb.Name = "BotLabel"
    bb.Size = UDim2.fromOffset(160, 40)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 150
    bb.Enabled = BotService.Debug
    bb.Parent = model:FindFirstChild("Head") or model
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = TEAM_COLORS[bot.Team]
    lbl.TextStrokeTransparency = 0.3
    lbl.Text = bot.Archetype
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
                table.insert(out, { Character = c, Humanoid = h, Root = r })
            end
        end
    end
    for _, b in BotService.Bots do
        if b.Alive and b.Team == otherTeam(team) and b.Character.Parent then
            local r = b.Character:FindFirstChild("HumanoidRootPart")
            if r then
                table.insert(out, { Character = b.Character, Humanoid = b.Humanoid, Root = r })
            end
        end
    end
    return out
end

local function canSee(bot, target)
    local root = bot.Root
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { bot.Character }
    local from = root.Position + Vector3.new(0, 1.5, 0)
    local hit = workspace:Raycast(from, target.Root.Position - from, params)
    return hit ~= nil and hit.Instance:IsDescendantOf(target.Character)
end

local function perceive(bot)
    local best, bestD
    for _, e in enemiesOf(bot.Team) do
        local d = (e.Root.Position - bot.Root.Position).Magnitude
        if d <= SIGHT and (not bestD or d < bestD) and canSee(bot, e) then
            best, bestD = e, d
        end
    end
    if best and not bot.Target then
        bot.FirstSeen = os.clock() -- reaction timer starts
    end
    if not best then
        bot.FirstSeen = nil
    end
    bot.Target, bot.TargetDist = best, bestD
end

-- ===== decision =====

local function zoneChoice(bot, zones)
    local pos = bot.Root.Position
    local best, bestScore
    for _, z in zones do
        if not z.Closed then
            local d = flat(z.Position - pos).Magnitude
            local score = d
            local mine = z.Owner == bot.Team
            if bot.Archetype == "Anchor" then
                -- defend what we hold; go take something only if we hold nothing
                score += mine and -300 or 0
            else
                -- attack what we do not hold, prefer contested
                score += mine and 250 or 0
                score += z.Contested and -150 or 0
            end
            if not bestScore or score < bestScore then
                best, bestScore = z, score
            end
        end
    end
    return best
end

local function decide(bot, zones)
    local hum = bot.Humanoid
    local hpFrac = hum.Health / hum.MaxHealth
    local now = os.clock()

    if bot.Reloading then
        bot.State = "Reload"
        return
    end
    if bot.Ammo <= 0 then
        bot.State = "Reload"
        bot.Reloading = true
        bot.ReloadDone = now + RELOAD_TIME
        return
    end
    if hpFrac < LOW_HEALTH and bot.Target and math.random() > bot.Level.Aggression then
        if bot.State ~= "Reposition" then
            bot.RepositionUntil = now + 3
        end
        bot.State = "Reposition"
        return
    end
    if bot.State == "Reposition" and now < (bot.RepositionUntil or 0) then
        return
    end

    local zone = zoneChoice(bot, zones)
    bot.Zone = zone
    local inZone = zone and flat(zone.Position - bot.Root.Position).Magnitude <= zone.Radius * 0.8

    if bot.Target and bot.TargetDist <= ENGAGE_RANGE and (now - (bot.FirstSeen or now)) >= bot.Level.Reaction then
        -- objective outranks chasing: an Anchor inside its zone engages from the zone; others engage freely
        bot.State = "Engage"
        return
    end
    if zone and inZone and (zone.Owner == bot.Team or bot.Archetype == "Anchor") then
        bot.State = "Defend"
        return
    end
    bot.State = "SeekObjective"
end

-- ===== navigation =====

local function computePath(bot, goal)
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
        bot.PathTime = os.clock()
        if bot.BlockedConn then
            bot.BlockedConn:Disconnect()
        end
        bot.BlockedConn = path.Blocked:Connect(function(idx)
            if idx >= (bot.WaypointIndex or 1) then
                bot.PathGoal = nil -- force repath next tick
            end
        end)
        return true
    end
    bot.Waypoints = nil
    bot.PathGoal = nil
    return false
end

local function flankPoint(bot, zone)
    -- approach from the side instead of straight on: offset perpendicular to the approach line
    local approach = flat(zone.Position - bot.Root.Position)
    if approach.Magnitude < 1 then
        return zone.Position
    end
    local side = Vector3.new(-approach.Unit.Z, 0, approach.Unit.X) * (bot.FlankSide or 1) * 35
    return zone.Position + side
end

local function navigateTo(bot, goal)
    local hum = bot.Humanoid
    local d = flat(goal - bot.Root.Position).Magnitude
    if d <= DIRECT_MOVE_RANGE then
        hum:MoveTo(goal)
        return
    end
    local stale = not bot.PathGoal or (bot.PathGoal - goal).Magnitude > 8 or os.clock() - (bot.PathTime or 0) > 4
    if stale then
        if not computePath(bot, goal) then
            hum:MoveTo(goal) -- straight line fallback
            return
        end
    end
    local wps = bot.Waypoints
    if not wps then
        hum:MoveTo(goal)
        return
    end
    local i = bot.WaypointIndex or 2
    local wp = wps[i]
    if not wp then
        hum:MoveTo(goal)
        return
    end
    if wp.Action == Enum.PathWaypointAction.Jump then
        hum.Jump = true
    end
    hum:MoveTo(wp.Position)
    if flat(wp.Position - bot.Root.Position).Magnitude < 4 then
        bot.WaypointIndex = i + 1
    end
end

local function stuckCheck(bot)
    local now = os.clock()
    if now - (bot.StuckAt or 0) < 1.5 then
        return
    end
    local moved = bot.LastPos and (bot.Root.Position - bot.LastPos).Magnitude or 99
    bot.LastPos = bot.Root.Position
    bot.StuckAt = now
    if moved < 2 and bot.State ~= "Defend" and bot.State ~= "Engage" then
        bot.Humanoid.Jump = true
        bot.PathGoal = nil -- repath
        bot.FlankSide = -(bot.FlankSide or 1)
    end
end

-- ===== combat =====

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

local function fire(bot)
    local target = bot.Target
    if not target or bot.Ammo <= 0 then
        return
    end
    local now = os.clock()
    -- burst control
    if bot.BurstLeft <= 0 then
        if now < (bot.NextBurst or 0) then
            return
        end
        local lo, hi = bot.Level.Burst[1], bot.Level.Burst[2]
        bot.BurstLeft = math.random(lo, hi)
    end
    if now - (bot.LastShot or 0) < SHOT_INTERVAL then
        return
    end
    bot.LastShot = now
    bot.BurstLeft -= 1
    bot.Ammo -= 1
    if bot.BurstLeft <= 0 then
        local g = bot.Level.BurstGap
        bot.NextBurst = now + g[1] + math.random() * (g[2] - g[1])
    end

    -- aim: angular error around the true direction, hit chance falls with distance
    local from = bot.Muzzle and bot.Muzzle.WorldPosition or (bot.Root.Position + Vector3.new(0.6, 1.2, 0))
    local aimAt = target.Root.Position + Vector3.new(0, 0.5, 0)
    local err = math.rad(bot.Level.AimError)
    local dir = (aimAt - from).Unit
    local jitter = CFrame.Angles((math.random() - 0.5) * 2 * err, (math.random() - 0.5) * 2 * err, 0)
    local shotDir = (CFrame.lookAt(from, from + dir) * jitter).LookVector
    tracer(from, from + shotDir * bot.TargetDist, TEAM_COLORS[bot.Team])

    local distFactor = math.clamp(1 - (bot.TargetDist - 15) / 80, 0.35, 1)
    if math.random() < bot.Level.Accuracy * distFactor then
        target.Character:SetAttribute("LastHitBy", bot.Id)
        target.Humanoid:TakeDamage(SHOT_DAMAGE)
    end
end

local function strafe(bot)
    local now = os.clock()
    if now > (bot.StrafeUntil or 0) then
        bot.StrafeDir = (math.random() < 0.5) and -1 or 1
        bot.StrafeUntil = now + 0.8 + math.random() * 0.7
    end
    local toTarget = flat(bot.Target.Root.Position - bot.Root.Position)
    if toTarget.Magnitude < 1 then
        return
    end
    local side = Vector3.new(-toTarget.Unit.Z, 0, toTarget.Unit.X) * bot.StrafeDir * 6
    -- keep a preferred distance: close in if far, back off if very close
    local push = Vector3.zero
    if bot.TargetDist > 30 then
        push = toTarget.Unit * 6
    elseif bot.TargetDist < 10 then
        push = -toTarget.Unit * 6
    end
    bot.Humanoid:MoveTo(bot.Root.Position + side + push)
end

local function faceTarget(bot)
    local t = bot.Target.Root.Position
    bot.Humanoid.AutoRotate = false
    bot.Root.CFrame = CFrame.lookAt(bot.Root.Position, Vector3.new(t.X, bot.Root.Position.Y, t.Z))
end

-- ===== tick =====

local function act(bot)
    local hum = bot.Humanoid
    local state = bot.State
    if state == "Reload" then
        hum.AutoRotate = true
        if os.clock() >= (bot.ReloadDone or 0) then
            bot.Ammo = MAG
            bot.Reloading = false
        elseif bot.Zone then
            navigateTo(bot, bot.Zone.Position) -- keep moving while reloading
        end
    elseif state == "Engage" then
        faceTarget(bot)
        fire(bot)
        local farFromZone = bot.Zone and flat(bot.Zone.Position - bot.Root.Position).Magnitude > bot.Zone.Radius * 2
        if bot.Archetype == "Assault" and farFromZone then
            navigateTo(bot, bot.Zone.Position) -- Assault keeps pushing toward the objective while shooting
        else
            strafe(bot) -- Anchors hold the zone edge; others strafe in the open
        end
    elseif state == "Reposition" then
        hum.AutoRotate = true
        -- back away from the target toward our own side of the map
        local away = bot.Target and -flat(bot.Target.Root.Position - bot.Root.Position).Unit
            or Vector3.new(bot.Team == "Red" and -1 or 1, 0, 0)
        hum:MoveTo(bot.Root.Position + away * 18)
    elseif state == "Defend" then
        hum.AutoRotate = true
        if bot.Zone and math.random() < 0.1 then
            local off = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
            hum:MoveTo(bot.Zone.Position + off)
        end
    else -- SeekObjective
        hum.AutoRotate = true
        if bot.Zone then
            local goal = bot.Zone.Position
            if bot.Archetype == "Flanker" and flat(goal - bot.Root.Position).Magnitude > 50 then
                goal = flankPoint(bot, bot.Zone)
            end
            navigateTo(bot, goal)
        end
    end
    if bot.Label then
        bot.Label.Text = ("%s  %s  %d"):format(bot.Archetype, state, hum.Health)
    end
end

-- ===== lifecycle =====

function BotService:SpawnBot(bot, spawnCF)
    local model, hum = makeRig(bot)
    model:PivotTo(spawnCF + Vector3.new(0, 3, 0))
    model.Parent = workspace
    bot.Character, bot.Humanoid, bot.Root = model, hum, model:WaitForChild("HumanoidRootPart")
    bot.Alive = true
    bot.State = "SeekObjective"
    bot.Ammo, bot.BurstLeft, bot.Reloading = MAG, 0, false
    bot.Target, bot.Zone, bot.Waypoints, bot.PathGoal = nil, nil, nil, nil
    bot.FlankSide = (math.random() < 0.5) and -1 or 1
    -- server keeps physics ownership so behaviour is consistent
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            pcall(function()
                d:SetNetworkOwner(nil)
            end)
        end
    end
    hum.Died:Connect(function()
        bot.Alive = false
        if bot.BlockedConn then
            bot.BlockedConn:Disconnect()
        end
        local killerId = model:GetAttribute("LastHitBy")
        local conv = Knit.GetService("ConvergenceService")
        if conv.CreditKill then
            conv:CreditKill(killerId, bot.Team)
        end
        task.delay(3, function()
            model:Destroy()
        end)
        task.delay(self.RespawnSeconds or 5, function()
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
    local level = LEVELS[self.Level] or LEVELS.Normal
    for _, team in { "Red", "Blue" } do
        for i = 1, perTeam do
            nextId -= 1
            local bot = {
                Name = ("%s Bot %d"):format(team, i),
                Team = team,
                Id = nextId,
                Alive = false,
                Level = level,
                Archetype = ARCHETYPES[((i - 1) % #ARCHETYPES) + 1],
            }
            table.insert(self.Bots, bot)
            self:SpawnBot(bot, self:SpawnFor(team))
        end
    end

    -- perception + decision at 5 Hz, action every heartbeat
    local acc = 0
    self.Conn = RunService.Heartbeat:Connect(function(dt)
        if not self.Active then
            return
        end
        acc += dt
        local slow = acc >= 0.2
        if slow then
            acc = 0
        end
        local zones = getZones()
        for _, bot in self.Bots do
            if bot.Alive and bot.Character.Parent and bot.Root.Parent then
                local ok, err = pcall(function()
                    if slow then
                        perceive(bot)
                        decide(bot, zones)
                        stuckCheck(bot)
                    end
                    act(bot)
                end)
                if not ok then
                    warn("[Bots] " .. tostring(err))
                end
            end
        end
    end)
end

function BotService:Stop()
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
                if LEVELS[name] then
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
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return BotService
