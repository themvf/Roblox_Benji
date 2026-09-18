-- Test bots for Convergence. Server-spawned R15 rigs that path to objectives, stand on them,
-- shoot enemies in line of sight, die, and respawn. They count for capture and score like players.
-- Enable with the chat command "/bots N" in the lobby (N per team) or Tuning: Convergence_BotsPerTeam.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BotService = Knit.CreateService({ Name = "BotService" })

BotService.PerTeam = 0
BotService.Bots = {} -- array of { Name, Team, Id, Character, Humanoid, Alive }

local TEAM_COLORS = { Red = Color3.fromRGB(255, 70, 70), Blue = Color3.fromRGB(70, 140, 255) }
local THINK = 0.5
local SIGHT = 45 -- studs
local DAMAGE_PER_SHOT = 7
local SHOT_INTERVAL = 0.5
local nextId = -1000

local function otherTeam(t)
    return t == "Red" and "Blue" or "Red"
end

local function makeRig(name, team)
    local desc = Instance.new("HumanoidDescription")
    local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    model.Name = name
    local hum = model:FindFirstChildOfClass("Humanoid")
    hum.DisplayName = name
    hum.WalkSpeed = 16
    hum.BreakJointsOnDeath = false
    -- team colour on the torso + outline so bots read like players
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") and (d.Name:find("Torso") or d.Name:find("Arm") or d.Name:find("Leg")) then
            d.Color = TEAM_COLORS[team]
        end
    end
    local hl = Instance.new("Highlight")
    hl.FillTransparency = 1
    hl.OutlineColor = TEAM_COLORS[team]
    hl.OutlineTransparency = 0.2
    hl.Parent = model
    model:SetAttribute("Team", team)
    model:SetAttribute("Bot", true)
    return model, hum
end

-- ===== targeting helpers (players + bots) =====

local function enemiesOf(team)
    local out = {}
    for _, p in Players:GetPlayers() do
        if p:GetAttribute("InMatch") and p:GetAttribute("Team") == otherTeam(team) then
            local c = p.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                table.insert(out, { Character = c, Humanoid = h, Root = r, Player = p })
            end
        end
    end
    for _, b in BotService.Bots do
        if b.Alive and b.Team == otherTeam(team) and b.Character.Parent then
            table.insert(
                out,
                { Character = b.Character, Humanoid = b.Humanoid, Root = b.Character.HumanoidRootPart, Bot = b }
            )
        end
    end
    return out
end

local function canSee(fromPos, target, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local dir = target.Root.Position - fromPos
    local hit = workspace:Raycast(fromPos, dir, params)
    return hit and hit.Instance:IsDescendantOf(target.Character)
end

local function tracer(from, to, color)
    local d = (to - from).Magnitude
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Size = Vector3.new(0.08, 0.08, d)
    p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -d / 2)
    p.Parent = workspace
    Debris:AddItem(p, 0.08)
end

-- ===== brain =====

local function pickZone(bot, zones)
    -- nearest live zone that is not ours (or is contested); else nearest live zone
    local root = bot.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end
    local best, bestD
    for _, z in zones do
        if not z.Closed then
            local want = z.Owner ~= bot.Team or z.Contested
            local d = (z.Position - root.Position).Magnitude + (want and 0 or 200)
            if not bestD or d < bestD then
                best, bestD = z, d
            end
        end
    end
    return best
end

local function think(bot, getZones)
    local hum, char = bot.Humanoid, bot.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or hum.Health <= 0 then
        return
    end

    -- 1. fight if an enemy is visible
    local enemies = enemiesOf(bot.Team)
    local target, targetD
    for _, e in enemies do
        local d = (e.Root.Position - root.Position).Magnitude
        if
            d <= SIGHT
            and (not targetD or d < targetD)
            and canSee(root.Position + Vector3.new(0, 1.5, 0), e, { char })
        then
            target, targetD = e, d
        end
    end
    if target then
        bot.Target = target
        root.CFrame =
            CFrame.lookAt(root.Position, Vector3.new(target.Root.Position.X, root.Position.Y, target.Root.Position.Z))
        if os.clock() - (bot.LastShot or 0) >= SHOT_INTERVAL then
            bot.LastShot = os.clock()
            tracer(root.Position + Vector3.new(0.6, 1.2, 0), target.Root.Position, TEAM_COLORS[bot.Team])
            if math.random() < 0.65 then -- bot accuracy
                target.Character:SetAttribute("LastHitBy", bot.Id)
                target.Humanoid:TakeDamage(DAMAGE_PER_SHOT)
            end
        end
        -- keep moving toward the zone while shooting if not already in one
    end

    -- 2. move toward the best zone
    local zone = pickZone(bot, getZones())
    if not zone then
        return
    end
    local flat = zone.Position - root.Position
    flat = Vector3.new(flat.X, 0, flat.Z)
    if flat.Magnitude <= zone.Radius * 0.6 then
        -- inside: small random shuffle so bots do not stack on one point
        if math.random() < 0.15 then
            local off = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
            hum:MoveTo(zone.Position + off)
        end
        return
    end
    -- repath every few thinks or when the goal changed
    if bot.Goal ~= zone or os.clock() - (bot.LastPath or 0) > 3 then
        bot.Goal = zone
        bot.LastPath = os.clock()
        local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
        local ok = pcall(function()
            path:ComputeAsync(root.Position, zone.Position)
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            bot.Waypoints = path:GetWaypoints()
            bot.WaypointIndex = 2
        else
            bot.Waypoints = nil
            hum:MoveTo(zone.Position) -- straight line fallback
        end
    end
    local wps = bot.Waypoints
    if wps then
        local i = bot.WaypointIndex or 2
        local wp = wps[i]
        if wp then
            if wp.Action == Enum.PathWaypointAction.Jump then
                hum.Jump = true
            end
            hum:MoveTo(wp.Position)
            if
                (Vector3.new(wp.Position.X, 0, wp.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
                < 4
            then
                bot.WaypointIndex = i + 1
            end
        end
    end
end

-- ===== lifecycle =====

function BotService:SpawnBot(bot, spawnCF)
    local model, hum = makeRig(bot.Name, bot.Team)
    model:PivotTo(spawnCF + Vector3.new(0, 3, 0))
    model.Parent = workspace
    bot.Character, bot.Humanoid, bot.Alive = model, hum, true
    bot.Goal, bot.Waypoints = nil, nil
    hum.Died:Connect(function()
        bot.Alive = false
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

-- Called by ConvergenceService at match start. getZones returns the live zone list.
function BotService:Start(perTeam, respawnSeconds, getZones)
    self:Stop()
    self.Active = true
    self.RespawnSeconds = respawnSeconds
    for _, team in { "Red", "Blue" } do
        for i = 1, perTeam do
            nextId -= 1
            local bot = { Name = ("%s Bot %d"):format(team, i), Team = team, Id = nextId, Alive = false }
            table.insert(self.Bots, bot)
            self:SpawnBot(bot, self:SpawnFor(team))
        end
    end
    task.spawn(function()
        while self.Active do
            for _, bot in self.Bots do
                if bot.Alive and bot.Character.Parent then
                    local ok, err = pcall(think, bot, getZones)
                    if not ok then
                        warn("[Bots] " .. tostring(err))
                    end
                end
            end
            task.wait(THINK)
        end
    end)
end

function BotService:Stop()
    self.Active = false
    for _, b in self.Bots do
        if b.Character then
            b.Character:Destroy()
        end
    end
    self.Bots = {}
end

-- For capture counting: bots alive inside a zone, per team
function BotService:CountInZone(zone)
    local counts = { Red = 0, Blue = 0 }
    for _, b in self.Bots do
        if b.Alive and b.Character.Parent then
            local root = b.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = root.Position - zone.Position
                if Vector3.new(d.X, 0, d.Z).Magnitude <= zone.Radius and math.abs(d.Y) <= 12 then
                    counts[b.Team] += 1
                end
            end
        end
    end
    return counts
end

function BotService:KnitStart()
    local function watch(player)
        player.Chatted:Connect(function(msg)
            local n = msg:match("^/bots%s+(%d+)")
            if n then
                self.PerTeam = tonumber(n)
                ReplicatedStorage:FindFirstChild("Tuning"):SetAttribute("Convergence_BotsPerTeam", self.PerTeam)
            end
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return BotService
