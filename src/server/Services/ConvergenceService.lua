-- Convergence: the featured objective mode. Generic over any map that declares Objectives.
--   zones (capture bar, owner, contested), phases that close zones 3 -> 2 -> 1,
--   team score from held zones and kills, respawns with spawn protection,
--   hard cap with overtime, then celebrations and back to the lobby.
-- Rules live in Config.Convergence (Tuning overrides apply live at match start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Config = require(ReplicatedStorage.Shared.Config)
local FinalePlan = require(script.Parent.Parent.FinalePlan)
local matchSerial = 0

local function zoneLive(match, zone, phase)
    if match.FinalePlan then
        return FinalePlan.live(match.FinalePlan, zone.Id, phase)
    end
    return table.find(zone.Phases, phase) ~= nil
end
local BotService
local StatsService

local ConvergenceService = Knit.CreateService({
    Name = "ConvergenceService",
    Client = {
        State = Knit.CreateSignal(), -- (snapshot) ~4 Hz to match participants
        Event = Knit.CreateSignal(), -- (kind, data) banners: ZoneCaptured, ZoneClosing, ZoneClosed, Phase, Overtime
    },
})

local TEAM_COLORS = {
    Red = Palette.Ui.Red,
    Blue = Palette.Ui.Blue,
    Neutral = Color3.fromRGB(140, 150, 168), -- muted slate, NOT white: white neon + bloom blows out
    Closed = Color3.fromRGB(70, 70, 75),
}

-- One shape per objective index: cube, diamond (a cube stood on its corner), sphere. Distinct in
-- silhouette from any angle, and each has an exact 2D equivalent the HUD draws (square, diamond,
-- circle) so the world and the HUD teach the same vocabulary.
local GLYPH_SHAPE = {
    [1] = { shape = Enum.PartType.Block, tilt = false },
    [2] = { shape = Enum.PartType.Block, tilt = true },
    [3] = { shape = Enum.PartType.Ball, tilt = false },
    [4] = { shape = Enum.PartType.Cylinder, tilt = false },
}

local TICK = 0.25

ConvergenceService.Busy = false

-- ===== zone visuals =====

local function makeZoneVisual(folder, zone)
    local pos = zone.Position
    -- Ownership is carried by the PERIMETER, not by flooding the floor. A saturated filled disc
    -- the size of a capture zone can occupy a large share of the screen, and once a team owns a
    -- point that one surface drowns out every other use of their colour. The fill stays as a
    -- faint tint for "this is the area"; the edge does the talking.
    local ring = Instance.new("Part")
    ring.Name = "Ring_" .. zone.Name
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.Material = Enum.Material.SmoothPlastic -- not Neon: a neon floor blooms
    ring.Transparency = 0.88
    ring.Size = Vector3.new(0.4, zone.Radius * 2, zone.Radius * 2)
    ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring.Color = TEAM_COLORS.Neutral
    ring.Parent = folder

    -- Perimeter built from segments: Roblox has no torus, and a slightly larger disc behind the
    -- first would just be more floor. 48 segments reads as a clean circle at any distance.
    local SEGMENTS = 48
    local rim = {}
    local seglen = (2 * math.pi * zone.Radius) / SEGMENTS * 1.15 -- overlap so there are no gaps
    for i = 1, SEGMENTS do
        local angle = (i / SEGMENTS) * math.pi * 2
        local seg = Instance.new("Part")
        seg.Name = "Rim" .. i
        seg.Anchored = true
        seg.CanCollide = false
        seg.CanQuery = false
        seg.Material = Enum.Material.Neon
        seg.Size = Vector3.new(seglen, 0.35, 0.9)
        seg.CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * zone.Radius, 0.25, math.sin(angle) * zone.Radius))
            * CFrame.Angles(0, -angle, 0)
        seg.Color = TEAM_COLORS.Neutral
        seg.Parent = folder
        table.insert(rim, seg)
    end

    local pillar = Instance.new("Part")
    pillar.Name = "Pillar_" .. zone.Name
    pillar.Anchored = true
    pillar.CanCollide = false
    pillar.CanQuery = false
    pillar.Material = Enum.Material.Neon
    pillar.Transparency = 0.86
    pillar.Size = Vector3.new(1, 46, 1)
    pillar.CFrame = CFrame.new(pos + Vector3.new(0, 30, 0))
    pillar.Color = TEAM_COLORS.Neutral
    pillar.Parent = folder

    -- No name sign: the zone identifies itself by SHAPE and by how many pips it carries, so it
    -- reads the same in every language and at any distance. Shape and pip count are redundant
    -- encodings of the same index, which keeps it legible for colour-blind players too.
    local glyph = Instance.new("Part")
    glyph.Name = "Glyph_" .. zone.Name
    glyph.Anchored = true
    glyph.CanCollide = false
    glyph.CanQuery = false
    glyph.Material = Enum.Material.Neon
    local g = GLYPH_SHAPE[zone.Index] or GLYPH_SHAPE[3]
    glyph.Shape = g.shape
    glyph.Size = Vector3.new(4.5, 4.5, 4.5)
    glyph.CFrame = CFrame.new(pos + Vector3.new(0, 13, 0))
        * (g.tilt and CFrame.Angles(math.rad(45), 0, math.rad(45)) or CFrame.identity)
    glyph.Color = TEAM_COLORS.Neutral
    glyph.Parent = folder

    -- capture progress stays, as a bar with no text
    local sign = Instance.new("BillboardGui")
    sign.Size = UDim2.fromOffset(200, 24)
    sign.StudsOffset = Vector3.new(0, 6.5, 0)
    sign.AlwaysOnTop = true
    sign.MaxDistance = 250
    sign.Parent = ring
    local barBack = Instance.new("Frame")
    barBack.Position = UDim2.fromScale(0.1, 0.3)
    barBack.Size = UDim2.fromScale(0.8, 0.4)
    barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    barBack.BorderSizePixel = 0
    barBack.Parent = sign
    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromScale(0, 1)
    bar.BackgroundColor3 = TEAM_COLORS.Neutral
    bar.BorderSizePixel = 0
    bar.Parent = barBack

    local finalSign = Instance.new("BillboardGui")
    finalSign.Name = "FinalDistrict"
    finalSign.Size = UDim2.fromOffset(220, 44)
    finalSign.StudsOffset = Vector3.new(0, 5, 0)
    finalSign.AlwaysOnTop = true
    finalSign.MaxDistance = 650
    finalSign.Enabled = false
    finalSign.Parent = glyph
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    label.BackgroundTransparency = 0.1
    label.TextColor3 = Color3.fromRGB(255, 220, 120)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.TextWrapped = true
    label.Text = "FINAL DISTRICT\n" .. zone.Name
    label.Parent = finalSign
    glyph:SetAttribute("ObjectiveId", zone.Id)
    zone.Visual = { Ring = ring, Rim = rim, Pillar = pillar, Bar = bar, Glyph = glyph, FinalSign = finalSign }
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
    v.FinalSign.Enabled = zone.IsFinal == true and not zone.Closed
    v.Ring.Transparency = zone.Closed and 0.95 or 0.88 -- the fill never gets loud, owned or not
    for _, seg in v.Rim or {} do
        seg.Color = color
        seg.Transparency = zone.Closed and 0.8 or 0
    end
    v.Pillar.Color = color
    v.Pillar.Transparency = zone.Closed and 0.97 or (zone.Contested and 0.66 or 0.86)
    -- bar shows progress toward Capturing team (or owner when idle)
    local team = zone.Capturing or zone.Owner
    v.Bar.BackgroundColor3 = team and TEAM_COLORS[team] or TEAM_COLORS.Neutral
    v.Bar.Size = UDim2.fromScale(math.clamp(zone.Progress / 100, 0, 1), 1)
    -- the glyph carries ownership; a closed zone goes dim and hollow rather than saying "CLOSED"
    if v.Glyph then
        v.Glyph.Color = color
        v.Glyph.Transparency = zone.Closed and 0.75 or 0
        v.Glyph.Material = zone.Closed and Enum.Material.Glass or Enum.Material.Neon
    end
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
                if Vector3.new(d.X, 0, d.Z).Magnitude <= zone.Radius and math.abs(d.Y) <= (zone.HalfHeight or 12) then
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
    if zone.Contested then
        zone.LastContestedAt = os.clock()
    end
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
            Id = z.Id,
            Name = z.Name,
            Owner = z.Owner,
            Capturing = z.Capturing,
            Progress = z.Progress,
            Contested = z.Contested,
            Closed = z.Closed,
            Index = z.Index,
            Live = zoneLive(match, z, match.Phase),
            IsFinal = FinalePlan.visibleFinal(match.FinalePlan, match.Phase) == z.Id and z.Id ~= nil,
        })
    end
    return {
        MatchId = match.Id,
        FinalDistrictId = FinalePlan.visibleFinal(match.FinalePlan, match.Phase),
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
    BotService = BotService or Knit.GetService("BotService")
    StatsService = StatsService or Knit.GetService("StatsService")
    local RoundService = Knit.GetService("RoundService")
    if self.Busy or RoundService.Busy then
        return false
    end
    self.Busy = true
    RoundService.Busy = true
    local rules = Config.GetConvergence()
    local MapService = Knit.GetService("MapService")

    matchSerial += 1
    local match = {
        Id = matchSerial,
        Players = players,
        Score = { Red = 0, Blue = 0 },
        Telemetry = { Outposts = {}, ScoreByPhase = {}, AreaTime = {} },
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
    Knit.GetService("MutationService"):StartMatch(players)
    Knit.GetService("AbilityService"):ResetTelemetry()

    -- players inside a zone (for score credit)
    local function insideZone(zone, p)
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            return false
        end
        local d = root.Position - zone.Position
        return Vector3.new(d.X, 0, d.Z).Magnitude <= zone.Radius and math.abs(d.Y) <= (zone.HalfHeight or 12)
    end
    local function playersInside(zone, team)
        local out = {}
        for _, p in present(match) do
            if (team == nil or p:GetAttribute("Team") == team) and insideZone(zone, p) then
                table.insert(out, p)
            end
        end
        return out
    end

    task.spawn(function()
        -- The players agree on the map first; a forced map (/map) skips the vote.
        mapName = Knit.GetService("MapVoteService")
            :Pick(players, Config.ConvergenceMaps, mapName, MapService.CurrentMap)
        local layout = require(ReplicatedStorage.Shared.Maps[mapName])
        local plan, planError = FinalePlan.create(mapName, layout.Objectives or {}, layout.Finale)
        if planError then
            warn("[Convergence] finale preflight failed for " .. mapName .. ": " .. planError)
            self:Finish(match, nil, true)
            return
        end
        match.FinalePlan = plan
        -- stats record the map that was actually voted in, so this waits for the vote
        StatsService:StartMatch(players, "Convergence", mapName)
        -- Map + intermission
        MapService:Load(mapName)
        RoundService:Broadcast(
            "Intermission",
            { Time = Config.IntermissionSeconds, Mode = "Convergence", Map = mapName, Vista = MapService.Vista }
        )
        local objectives = MapService.Objectives or {}
        if #objectives == 0 then
            warn("[Convergence] map " .. mapName .. " has no Objectives; aborting")
            self:Finish(match, nil, true)
            return
        end
        local folder = Instance.new("Folder")
        folder.Name = "Objectives"
        folder.Parent = workspace
        for i, o in objectives do
            local zone = {
                Id = o.Id,
                Name = o.Name,
                Index = i,
                Position = o.Position,
                Radius = o.Radius,
                HalfHeight = o.HalfHeight,
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
                            local outpost = killer:GetAttribute("AtOutpost")
                            if outpost and match.Telemetry.Outposts[outpost] then
                                match.Telemetry.Outposts[outpost].Kills += 1
                            end
                        end
                        local root = character:FindFirstChild("HumanoidRootPart")
                        if root then
                            Knit.GetService("PickupService"):NoteDeath(root.Position)
                        end
                        StatsService:OnKill((killer and killer ~= p) and killer or nil, p, character)
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

        -- Signature map events: fire those whose TriggerPhase matches, kill anyone inside the region
        local hazards = {} -- list of inside(position) functions
        local function fireEventsForPhase(phase)
            for _, ev in MapService.Events or {} do
                if ev.TriggerPhase == phase and ev.Kind == "Kraken" then
                    -- S10: visual spectacle only in v1
                    self:FireAll(match, self.Client.Event, "MapEventStart", { Name = ev.Name, Banner = ev.Banner })
                    Knit.GetService("AmbientService"):Kraken(ev)
                elseif ev.TriggerPhase == phase then
                    if ev.Flyover then
                        Knit.GetService("AmbientService"):Flyover({ Low = true, Speed = 260 })
                    end
                    local inside = MapService:RunEvent(ev, {
                        onWarning = function()
                            self:FireAll(
                                match,
                                self.Client.Event,
                                "MapEventWarning",
                                { Name = ev.Name, Banner = ev.Banner, Seconds = ev.WarningSeconds }
                            )
                        end,
                        onStart = function()
                            self:FireAll(
                                match,
                                self.Client.Event,
                                "MapEventStart",
                                { Name = ev.Name, Banner = ev.Banner }
                            )
                        end,
                        onEnd = function()
                            self:FireAll(match, self.Client.Event, "MapEventEnd", { Name = ev.Name })
                        end,
                    })
                    table.insert(hazards, inside)
                end
            end
        end
        fireEventsForPhase(1)

        -- Test bots: fill each team with N bots that capture, shoot and respawn
        local botsPerTeam = rules.BotsPerTeam or 0
        if botsPerTeam > 0 then
            BotService:Start(botsPerTeam, rules.RespawnSeconds, function()
                return match.Zones
            end)
        end

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
                local live = zoneLive(match, zone, match.Phase)
                if not live and not zone.Closed then
                    zone.Closed = true
                    zone.Capturing = nil
                    paintZone(zone)
                    self:FireAll(match, self.Client.Event, "ZoneClosed", { Zone = zone.Name, Index = zone.Index })
                end
                if live and not zone.Closed then
                    local counts = playersIn(zone, teamOf)
                    local botCounts = BotService:CountInZone(zone)
                    counts.Red += botCounts.Red
                    counts.Blue += botCounts.Blue
                    local ev = stepZone(zone, counts, rules, dt)
                    if ev == "Captured" then
                        self:FireAll(
                            match,
                            self.Client.Event,
                            "ZoneCaptured",
                            { Zone = zone.Name, Team = zone.Owner, Index = zone.Index }
                        )
                        StatsService:OnCapture(zone, playersInside(zone, zone.Owner))
                    elseif ev == "Neutralized" then
                        self:FireAll(
                            match,
                            self.Client.Event,
                            "ZoneNeutralized",
                            { Zone = zone.Name, Index = zone.Index }
                        )
                        StatsService:OnStop(zone, playersInside(zone, nil))
                    end
                    paintZone(zone)
                    if zone.Owner and not zone.Contested then
                        liveOwned[zone.Owner] += 1
                    end
                end
            end

            -- Score from held zones. A CONTESTED zone pays nobody: zone.Contested was computed
            -- every tick and the scoring loop never read it, so walking onto an enemy point froze
            -- their capture bar while they kept banking full income and the attacker earned
            -- nothing until a total wipe. With no decay and empty-hold scoring on top, holding
            -- was close to unbreakable. Contesting now costs the holder immediately.
            match.Score.Red += liveOwned.Red * rules.PointsPerZonePerSecond * dt
            match.Score.Blue += liveOwned.Blue * rules.PointsPerZonePerSecond * dt

            -- clocks
            if not match.Overtime then
                match.TimeLeft = math.max(0, match.TimeLeft - dt)
                match.PhaseTimeLeft -= dt
                -- closing warning for the zone(s) that will not survive the next phase
                if
                    match.Phase < phaseCount
                    and match.PhaseTimeLeft <= rules.ZoneCloseWarningSeconds
                    and not (match.FinalePlan and match.Phase == 1)
                then
                    for _, zone in match.Zones do
                        if not zone.Closed and not zoneLive(match, zone, match.Phase + 1) and not warned[zone.Name] then
                            warned[zone.Name] = true
                            self:FireAll(
                                match,
                                self.Client.Event,
                                "ZoneClosing",
                                { Zone = zone.Name, Index = zone.Index, Seconds = rules.ZoneCloseWarningSeconds }
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
                -- In the final phase there is no next phase to advance to, so PhaseTimeLeft
                -- used to run negative for the rest of the match: the clock clamped to 0:00 and
                -- PhaseSeconds (540) silently under-declared the real 720 s match by 180 s.
                -- The final phase now simply IS the remaining match time, so it is truthful.
                if match.Phase >= phaseCount then
                    match.PhaseTimeLeft = match.TimeLeft
                end
                if match.PhaseTimeLeft <= 0 and match.Phase < phaseCount then
                    match.Telemetry.ScoreByPhase[match.Phase] =
                        { Red = math.floor(match.Score.Red), Blue = math.floor(match.Score.Blue) }
                    match.Phase += 1
                    match.PhaseTimeLeft = rules.PhaseSeconds[match.Phase]
                    -- Close atomically with the phase transition, retaining survivor ownership/progress.
                    local revealed = match.FinalePlan and match.Phase == 2 and FinalePlan.reveal(match.FinalePlan)
                    local finalZone
                    for _, zone in match.Zones do
                        if not zoneLive(match, zone, match.Phase) and not zone.Closed then
                            zone.Closed = true
                            zone.Capturing = nil
                            self:FireAll(
                                match,
                                self.Client.Event,
                                "ZoneClosed",
                                { Zone = zone.Name, Index = zone.Index }
                            )
                        end
                        zone.IsFinal = FinalePlan.visibleFinal(match.FinalePlan, match.Phase) == zone.Id
                            and zone.Id ~= nil
                        if zone.IsFinal then
                            finalZone = zone
                        end
                        paintZone(zone)
                    end
                    self:FireAll(
                        match,
                        self.Client.Event,
                        "Phase",
                        { Phase = match.Phase, Zones = phaseCount - match.Phase + 1 }
                    )
                    fireEventsForPhase(match.Phase)
                    if revealed and finalZone then
                        self:FireAll(match, self.Client.Event, "FinaleRevealed", {
                            MatchId = match.Id,
                            Id = finalZone.Id,
                            Name = finalZone.Name,
                            Index = finalZone.Index,
                        })
                    end
                    self:FireAll(match, self.Client.State, self:Snapshot(match))
                end
            end

            -- S22 telemetry: sniper outpost occupancy (players + bots)
            for _, o in MapService.SniperOutposts or {} do
                match.Telemetry.Outposts[o.Name] = match.Telemetry.Outposts[o.Name] or { Seconds = 0, Kills = 0 }
                for _, p in present(match) do
                    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if root and (root.Position - o.Position).Magnitude <= o.Radius then
                        match.Telemetry.Outposts[o.Name].Seconds += dt
                        p:SetAttribute("AtOutpost", o.Name)
                    elseif root and p:GetAttribute("AtOutpost") == o.Name then
                        p:SetAttribute("AtOutpost", nil)
                    end
                end
            end

            -- Lethal map-event regions
            if #hazards > 0 then
                for _, p in present(match) do
                    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                    if root and hum and hum.Health > 0 then
                        for _, inside in hazards do
                            if inside(root.Position) then
                                hum:TakeDamage(hum.MaxHealth * 0.6 * dt) -- lethal in under 2 s
                                break
                            end
                        end
                    end
                end
            end
            if match.Overtime then
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

            -- match score credit + bounty pings + scoreboard
            StatsService:Tick(dt, match.Zones, insideZone)
            match.PingClock = (match.PingClock or 0) + dt
            if match.PingClock >= 75 then
                match.PingClock = 0
                StatsService:PingBounties(match.Zones)
            end
            match.BoardClock = (match.BoardClock or 0) + dt
            if match.BoardClock >= 1 then
                match.BoardClock = 0
                StatsService:BroadcastScoreboard()
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

-- Credit a kill on a bot (or any non-player victim) to the killer's team
function ConvergenceService:CreditKill(killerId, victimTeam)
    local match = self.Match
    if not match or not match.Running then
        return
    end
    local killer = killerId and killerId > 0 and Players:GetPlayerByUserId(killerId)
    if killer and killer:GetAttribute("InMatch") then
        local kteam = killer:GetAttribute("Team")
        if kteam and kteam ~= victimTeam then
            killer:SetAttribute("MatchKills", (killer:GetAttribute("MatchKills") or 0) + 1)
            match.Score[kteam] += match.Rules.KillPoints
            if StatsService then
                StatsService:OnKill(killer, nil, nil)
            end
        end
    elseif killerId and killerId < 0 then
        -- bot killed a bot: score for the bot's team
        local kteam = victimTeam == "Red" and "Blue" or "Red"
        match.Score[kteam] += match.Rules.KillPoints
    end
end

local function printMapTelemetry(match)
    local pk = Knit.GetService("PickupService").Stats or {}
    local lines = { "=== MAP REPORT ===" }
    match.Telemetry.ScoreByPhase[match.Phase] =
        { Red = math.floor(match.Score.Red), Blue = math.floor(match.Score.Blue) }
    for ph, sc in match.Telemetry.ScoreByPhase do
        table.insert(lines, ("phase %d  Red %d  Blue %d"):format(ph, sc.Red, sc.Blue))
    end
    local totalKills = 0
    for _, p in match.Players do
        totalKills += p:GetAttribute("MatchKills") or 0
    end
    for name, o in match.Telemetry.Outposts do
        local share = totalKills > 0 and (o.Kills / totalKills * 100) or 0
        table.insert(
            lines,
            ("outpost %-16s occupancy %.0fs  kills %d (%.0f%% of player kills; red flag > 25%%)"):format(
                name,
                o.Seconds,
                o.Kills,
                share
            )
        )
    end
    table.insert(
        lines,
        ("launch pads %d uses, %d deaths in flight | speed %d | jetpack %d | weapon %d | deaths near pickups %d"):format(
            pk.LaunchUses or 0,
            pk.LaunchDeathsInFlight or 0,
            pk.SpeedUses or 0,
            pk.JetpackUses or 0,
            pk.WeaponUses or 0,
            pk.DeathsNearPickups or 0
        )
    )
    print(table.concat(lines, "\n"))
end

function ConvergenceService:Finish(match, winner, aborted)
    BotService:Stop()
    if match.Telemetry then
        printMapTelemetry(match)
    end
    local RoundService = Knit.GetService("RoundService")
    RoundService:Broadcast(
        "MatchOver",
        { Score = match.Score, Mode = "Convergence", Winner = winner, Aborted = aborted }
    )
    if match.Folder then
        match.Folder:Destroy()
    end
    if not aborted and winner then
        -- validation, transparent MVP, streaks, XP and persistent stats live in StatsService
        Knit.GetService("MutationService"):EndMatch()
        StatsService:EndMatch(winner, aborted)
        task.wait(6) -- recap card on screen
        local winners, losers = {}, {}
        for _, p in present(match) do
            if p:GetAttribute("Team") == winner then
                table.insert(winners, p)
            else
                table.insert(losers, p)
            end
        end
        table.sort(winners, function(a, b)
            local sa, sb = a:GetAttribute("MatchScore") or 0, b:GetAttribute("MatchScore") or 0
            if sa ~= sb then
                return sa > sb
            end
            return a.UserId < b.UserId
        end)
        Knit.GetService("CelebrationService"):Run(winners, losers)
    else
        Knit.GetService("MutationService"):EndMatch()
        StatsService:Abort()
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
