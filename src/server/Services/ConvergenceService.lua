-- Convergence: the featured objective mode. Generic over any map that declares Objectives.
--   zones (capture bar, owner, contested), phases that close zones 3 -> 2 -> 1,
--   team score from held zones and kills, respawns with spawn protection,
--   hard cap with overtime, then celebrations and back to the lobby.
-- Rules live in Config.Convergence (Tuning overrides apply live at match start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local ConvergenceService = Knit.CreateService({
    Name = "ConvergenceService",
    Client = {
        State = Knit.CreateSignal(), -- (snapshot) ~4 Hz to match participants
        Event = Knit.CreateSignal(), -- (kind, data) banners: ZoneCaptured, ZoneClosing, ZoneClosed, Phase, Overtime
    },
})

local TEAM_COLORS = {
    Red = Color3.fromRGB(255, 70, 70),
    Blue = Color3.fromRGB(70, 140, 255),
    Neutral = Color3.fromRGB(220, 220, 225),
    Closed = Color3.fromRGB(70, 70, 75),
}

local TICK = 0.25

ConvergenceService.Busy = false

-- ===== zone visuals =====

local function makeZoneVisual(folder, zone)
    local pos = zone.Position
    local ring = Instance.new("Part")
    ring.Name = "Ring_" .. zone.Name
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.45
    ring.Size = Vector3.new(0.4, zone.Radius * 2, zone.Radius * 2)
    ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring.Color = TEAM_COLORS.Neutral
    ring.Parent = folder

    local pillar = Instance.new("Part")
    pillar.Name = "Pillar_" .. zone.Name
    pillar.Anchored = true
    pillar.CanCollide = false
    pillar.CanQuery = false
    pillar.Material = Enum.Material.Neon
    pillar.Transparency = 0.75
    pillar.Size = Vector3.new(1.5, 60, 1.5)
    pillar.CFrame = CFrame.new(pos + Vector3.new(0, 30, 0))
    pillar.Color = TEAM_COLORS.Neutral
    pillar.Parent = folder

    local sign = Instance.new("BillboardGui")
    sign.Size = UDim2.fromOffset(200, 70)
    sign.StudsOffset = Vector3.new(0, 10, 0)
    sign.AlwaysOnTop = true
    sign.MaxDistance = 400
    sign.Parent = ring
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 0.6)
    label.BackgroundTransparency = 1
    label.Text = zone.Name
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.Parent = sign
    local barBack = Instance.new("Frame")
    barBack.Position = UDim2.fromScale(0.1, 0.68)
    barBack.Size = UDim2.fromScale(0.8, 0.2)
    barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    barBack.BorderSizePixel = 0
    barBack.Parent = sign
    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromScale(0, 1)
    bar.BackgroundColor3 = TEAM_COLORS.Neutral
    bar.BorderSizePixel = 0
    bar.Parent = barBack

    zone.Visual = { Ring = ring, Pillar = pillar, Bar = bar, Label = label }
end

local function paintZone(zone)
    local v = zone.Visual
    if not v then
        return
    end
    local color
    if zone.Closed then
        color = TEAM_COLORS.Closed
    elseif zone.Owner then
        color = TEAM_COLORS[zone.Owner]
    else
        color = TEAM_COLORS.Neutral
    end
    v.Ring.Color = color
    v.Pillar.Color = color
    v.Pillar.Transparency = zone.Closed and 0.95 or (zone.Contested and 0.5 or 0.75)
    -- bar shows progress toward Capturing team (or owner when idle)
    local team = zone.Capturing or zone.Owner
    v.Bar.BackgroundColor3 = team and TEAM_COLORS[team] or TEAM_COLORS.Neutral
    v.Bar.Size = UDim2.fromScale(math.clamp(zone.Progress / 100, 0, 1), 1)
    v.Label.Text = zone.Closed and (zone.Name .. "  CLOSED") or zone.Name
end

-- ===== match =====

local function playersIn(zone, teamOf)
    local counts = { Red = 0, Blue = 0 }
    for _, p in Players:GetPlayers() do
        local team = teamOf(p)
        if team then
            local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local d = root.Position - zone.Position
                if Vector3.new(d.X, 0, d.Z).Magnitude <= zone.Radius and math.abs(d.Y) <= 12 then
                    counts[team] += 1
                end
            end
        end
    end
    return counts
end

local function otherTeam(t)
    return t == "Red" and "Blue" or "Red"
end

-- Advance one zone by dt. Returns an event name if something notable happened.
local function stepZone(zone, counts, rules, dt)
    if zone.Closed then
        return nil
    end
    local red, blue = counts.Red, counts.Blue
    zone.Contested = red > 0 and blue > 0
    if zone.Contested or (red == 0 and blue == 0) then
        return nil -- frozen while contested; holds while empty
    end
    local team = red > 0 and "Red" or "Blue"
    local n = math.min(team == "Red" and red or blue, rules.MaxStack)
    local speed = (100 / rules.CaptureSeconds) * (1 + rules.StackBonus * (n - 1))

    if zone.Owner == team then
        -- topping up own point after a partial enemy drain
        zone.Capturing = nil
        if zone.Progress < 100 then
            zone.Progress = math.min(100, zone.Progress + speed * dt)
        end
        return nil
    end

    if zone.Owner == otherTeam(team) then
        -- neutralize first: drain the enemy bar
        zone.Capturing = nil
        zone.Progress = zone.Progress - speed * dt
        if zone.Progress <= 0 then
            zone.Owner = nil
            zone.Progress = 0
            return "Neutralized"
        end
        return nil
    end

    -- neutral: fill toward this team
    if zone.Capturing ~= team then
        zone.Capturing = team
        zone.Progress = 0
    end
    zone.Progress = zone.Progress + speed * dt
    if zone.Progress >= 100 then
        zone.Owner = team
        zone.Capturing = nil
        zone.Progress = 100
        return "Captured"
    end
    return nil
end

function ConvergenceService:Snapshot(match)
    local zones = {}
    for _, z in match.Zones do
        table.insert(zones, {
            Name = z.Name,
            Owner = z.Owner,
            Capturing = z.Capturing,
            Progress = z.Progress,
            Contested = z.Contested,
            Closed = z.Closed,
            Live = table.find(z.Phases, match.Phase) ~= nil,
        })
    end
    return {
        Score = match.Score,
        Phase = match.Phase,
        PhaseTimeLeft = match.PhaseTimeLeft,
        TimeLeft = match.TimeLeft,
        Overtime = match.Overtime,
        Zones = zones,
        Mode = "Convergence",
    }
end

local function present(match)
    local out = {}
    for _, p in match.Players do
        if p.Parent == Players then
            table.insert(out, p)
        end
    end
    return out
end

function ConvergenceService:FireAll(match, signal, ...)
    for _, p in present(match) do
        signal:Fire(p, ...)
    end
end

-- players: Red first (teamSize of them) then Blue. Runs async; returns immediately.
function ConvergenceService:StartMatch(players, teamSize, mapName)
    local RoundService = Knit.GetService("RoundService")
    if self.Busy or RoundService.Busy then
        return false
    end
    self.Busy = true
    RoundService.Busy = true
    local rules = Config.GetConvergence()
    local MapService = Knit.GetService("MapService")

    local match = {
        Players = players,
        Score = { Red = 0, Blue = 0 },
        Phase = 1,
        PhaseTimeLeft = rules.PhaseSeconds and rules.PhaseSeconds[1] or 180,
        TimeLeft = rules.HardCapSeconds,
        Overtime = false,
        Zones = {},
        Rules = rules,
    }
    self.Match = match

    for i, player in players do
        player:SetAttribute("InMatch", true)
        player:SetAttribute("Team", i <= teamSize and "Red" or "Blue")
        player:SetAttribute("MatchKills", 0)
    end
    local function teamOf(p)
        if p:GetAttribute("InMatch") and table.find(match.Players, p) then
            return p:GetAttribute("Team")
        end
        return nil
    end

    task.spawn(function()
        -- Map + intermission
        RoundService:Broadcast(
            "Intermission",
            { Time = Config.IntermissionSeconds, Mode = "Convergence", Map = mapName }
        )
        MapService:Load(mapName)
        local objectives = MapService.Objectives or {}
        if #objectives == 0 then
            warn("[Convergence] map " .. mapName .. " has no Objectives; aborting")
            self:Finish(match, nil, true)
            return
        end
        local folder = Instance.new("Folder")
        folder.Name = "Objectives"
        folder.Parent = workspace
        for _, o in objectives do
            local zone = {
                Name = o.Name,
                Position = o.Position,
                Radius = o.Radius,
                Phases = o.Phases,
                Owner = nil,
                Progress = 0,
            }
            makeZoneVisual(folder, zone)
            table.insert(match.Zones, zone)
        end
        match.Folder = folder
        task.wait(Config.IntermissionSeconds)

        -- Spawn everyone, hook respawns and kills
        local conns = {}
        for _, p in present(match) do
            table.insert(
                conns,
                p.CharacterAdded:Connect(function(character)
                    local hum = character:WaitForChild("Humanoid")
                    -- spawn protection
                    local ff = Instance.new("ForceField")
                    ff.Visible = true
                    ff.Parent = character
                    task.delay(rules.SpawnProtectSeconds, function()
                        ff:Destroy()
                    end)
                    hum.Died:Connect(function()
                        local killerId = character:GetAttribute("LastHitBy")
                        local killer = killerId and Players:GetPlayerByUserId(killerId)
                        local kteam = killer and teamOf(killer)
                        if killer and killer ~= p and kteam and kteam ~= teamOf(p) then
                            killer:SetAttribute("MatchKills", (killer:GetAttribute("MatchKills") or 0) + 1)
                            match.Score[kteam] += rules.KillPoints
                        end
                        task.delay(rules.RespawnSeconds, function()
                            if match.Running and p.Parent and p:GetAttribute("InMatch") then
                                p:LoadCharacter()
                            end
                        end)
                    end)
                end)
            )
            p:LoadCharacter()
        end
        match.Running = true
        RoundService:Broadcast("Round", { Mode = "Convergence", Score = match.Score })
        self:FireAll(match, self.Client.Event, "Phase", { Phase = 1, Zones = 3 })

        -- Main loop
        local lastSnap = 0
        local warned = {}
        while match.Running do
            task.wait(TICK)
            local dt = TICK
            local phaseCount = #(rules.PhaseSeconds or { 180, 180, 180 })

            -- zones
            local liveOwned = { Red = 0, Blue = 0 }
            for _, zone in match.Zones do
                local live = table.find(zone.Phases, match.Phase) ~= nil
                if not live and not zone.Closed then
                    zone.Closed = true
                    zone.Capturing = nil
                    paintZone(zone)
                    self:FireAll(match, self.Client.Event, "ZoneClosed", { Zone = zone.Name })
                end
                if live and not zone.Closed then
                    local counts = playersIn(zone, teamOf)
                    local ev = stepZone(zone, counts, rules, dt)
                    if ev == "Captured" then
                        self:FireAll(match, self.Client.Event, "ZoneCaptured", { Zone = zone.Name, Team = zone.Owner })
                    elseif ev == "Neutralized" then
                        self:FireAll(match, self.Client.Event, "ZoneNeutralized", { Zone = zone.Name })
                    end
                    paintZone(zone)
                    if zone.Owner then
                        liveOwned[zone.Owner] += 1
                    end
                end
            end

            -- score from held zones
            match.Score.Red += liveOwned.Red * rules.PointsPerZonePerSecond * dt
            match.Score.Blue += liveOwned.Blue * rules.PointsPerZonePerSecond * dt

            -- clocks
            if not match.Overtime then
                match.TimeLeft -= dt
                match.PhaseTimeLeft -= dt
                -- closing warning for the zone(s) that will not survive the next phase
                if match.Phase < phaseCount and match.PhaseTimeLeft <= rules.ZoneCloseWarningSeconds then
                    for _, zone in match.Zones do
                        if
                            not zone.Closed
                            and not table.find(zone.Phases, match.Phase + 1)
                            and not warned[zone.Name]
                        then
                            warned[zone.Name] = true
                            self:FireAll(
                                match,
                                self.Client.Event,
                                "ZoneClosing",
                                { Zone = zone.Name, Seconds = rules.ZoneCloseWarningSeconds }
                            )
                            local v = zone.Visual
                            if v then
                                TweenService
                                    :Create(
                                        v.Pillar,
                                        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 30, true),
                                        { Transparency = 0.2 }
                                    )
                                    :Play()
                            end
                        end
                    end
                end
                if match.PhaseTimeLeft <= 0 and match.Phase < phaseCount then
                    match.Phase += 1
                    match.PhaseTimeLeft = rules.PhaseSeconds[match.Phase]
                    self:FireAll(
                        match,
                        self.Client.Event,
                        "Phase",
                        { Phase = match.Phase, Zones = phaseCount - match.Phase + 1 }
                    )
                end
            else
                match.OvertimeLeft -= dt
            end

            -- win checks
            local winner
            if match.Score.Red >= rules.ScoreToWin then
                winner = "Red"
            elseif match.Score.Blue >= rules.ScoreToWin then
                winner = "Blue"
            end
            local timeUp = (not match.Overtime and match.TimeLeft <= 0) or (match.Overtime and match.OvertimeLeft <= 0)
            if not winner and timeUp then
                -- overtime: final zone contested or trailing team has progress on it
                local final
                for _, zone in match.Zones do
                    if not zone.Closed then
                        final = zone
                    end
                end
                local trailing = match.Score.Red < match.Score.Blue and "Red" or "Blue"
                local extend = final
                    and not match.Overtime
                    and (
                        final.Contested
                        or (final.Capturing == trailing and final.Progress > 0)
                        or (final.Owner == otherTeam(trailing) and final.Progress < 100)
                    )
                if extend then
                    match.Overtime = true
                    match.OvertimeLeft = rules.OvertimeMaxSeconds
                    self:FireAll(match, self.Client.Event, "Overtime", {})
                elseif
                    not (match.Overtime and final and (final.Contested or final.Capturing) and match.OvertimeLeft > 0)
                then
                    -- resolved (or overtime exhausted): decide the winner
                    if match.Score.Red ~= match.Score.Blue then
                        winner = match.Score.Red > match.Score.Blue and "Red" or "Blue"
                    elseif final and final.Owner then
                        winner = final.Owner
                    else
                        winner = nil -- draw
                    end
                    match.Running = false
                end
            end
            if winner then
                match.Running = false
                match.Winner = winner
            end

            -- team-left abort
            local red, blue = 0, 0
            for _, p in present(match) do
                if p:GetAttribute("Team") == "Red" then
                    red += 1
                else
                    blue += 1
                end
            end
            if red == 0 or blue == 0 then
                match.Running = false
                match.Aborted = true
            end

            -- snapshot to clients
            if os.clock() - lastSnap >= 0.25 then
                lastSnap = os.clock()
                self:FireAll(match, self.Client.State, self:Snapshot(match))
            end
        end

        for _, c in conns do
            c:Disconnect()
        end
        self:Finish(match, match.Winner, match.Aborted)
    end)
    return true
end

function ConvergenceService:Finish(match, winner, aborted)
    local RoundService = Knit.GetService("RoundService")
    RoundService:Broadcast(
        "MatchOver",
        { Score = match.Score, Mode = "Convergence", Winner = winner, Aborted = aborted }
    )
    if match.Folder then
        match.Folder:Destroy()
    end
    if not aborted and winner then
        local winners, losers = {}, {}
        for _, p in present(match) do
            p:SetAttribute("Matches", (p:GetAttribute("Matches") or 0) + 1)
            p:SetAttribute("Kills", (p:GetAttribute("Kills") or 0) + (p:GetAttribute("MatchKills") or 0))
            if p:GetAttribute("Team") == winner then
                table.insert(winners, p)
                p:SetAttribute("Wins", (p:GetAttribute("Wins") or 0) + 1)
            else
                table.insert(losers, p)
            end
        end
        table.sort(winners, function(a, b)
            local ka, kb = a:GetAttribute("MatchKills") or 0, b:GetAttribute("MatchKills") or 0
            if ka ~= kb then
                return ka > kb
            end
            return a.UserId < b.UserId
        end)
        Knit.GetService("CelebrationService"):Run(winners, losers)
    else
        task.wait(2)
    end
    for _, p in present(match) do
        RoundService:SendToLobby(p)
    end
    self.Match = nil
    self.Busy = false
    RoundService.Busy = false
    RoundService:Broadcast("Lobby", {})
end

return ConvergenceService
