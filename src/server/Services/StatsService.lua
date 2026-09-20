-- Competitive loop, Phases 1-2: transparent match score + MVP, persistent stats, streaks with
-- checkpoints, public-match validation, combat and objective match bounties (XP/titles only),
-- team-aware payouts with basic anti-abuse, contextual bounty visibility, end-of-match recap.
-- Streak *bounties* (cross-match currency) are Phase 3 and intentionally not here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Progression = require(ReplicatedStorage.Shared.Progression)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)

local StatsService = Knit.CreateService({
    Name = "StatsService",
    Client = {
        Scoreboard = Knit.CreateSignal(), -- (rows) ~1 Hz to match participants
        Bounty = Knit.CreateSignal(), -- (kind, data): Set, Cleared, Ping, Claimed, Survived
        Recap = Knit.CreateSignal(), -- (recap) end of match, to each participant (personalised)
    },
})

local match = nil -- current match record

local function now()
    return os.clock()
end

local function tuning()
    return ReplicatedStorage:FindFirstChild("Tuning")
end

-- ===== match record =====
local function newEntry(player)
    return {
        Player = player,
        Team = player:GetAttribute("Team"),
        Objective = 0,
        Defense = 0,
        Teamplay = 0,
        Combat = 0,
        Discipline = 0,
        Kills = 0,
        Deaths = 0,
        Assists = 0,
        Captures = 0,
        Stops = 0,
        Damage = 0,
        LifeKills = 0,
        LifeCaptures = 0,
        LifeHoldSeconds = 0,
        DamageBy = {}, -- [dealerUserId] = damage on this player's current life
        Bounty = nil, -- { Kind, Name, XP, SetAt }
        PairKills = {}, -- [victimUserId] = count (anti-farm)
        JoinedAt = now(),
        IdleSeconds = 0,
        LastPos = nil,
    }
end

function StatsService:Entry(player)
    return match and match.Entries[player] or nil
end

function StatsService:Total(e)
    return math.floor(e.Objective + e.Defense + e.Teamplay + e.Combat + e.Discipline)
end

-- ===== hooks from ConvergenceService / damage sources =====
function StatsService:StartMatch(players, mode, mapName)
    match = { Entries = {}, Mode = mode, Map = mapName, StartedAt = now(), Bots = false, Kills = 0 }
    for _, p in players do
        match.Entries[p] = newEntry(p)
        p:SetAttribute("Bounty", nil)
        p:SetAttribute("MatchScore", 0)
    end
    local t = tuning()
    local bots = t and (t:GetAttribute("Convergence_BotsPerTeam") or 0) or 0
    match.Bots = bots > 0
end

-- called every server tick with zone states so we can credit hold / capture seconds
function StatsService:Tick(dt, zones, playersIn)
    if not match then
        return
    end
    local S = Progression.Score
    for p, e in match.Entries do
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.Health > 0 then
            -- idle tracking
            if e.LastPos and (root.Position - e.LastPos).Magnitude < 1 then
                e.IdleSeconds += dt
            else
                e.IdleSeconds = math.max(0, e.IdleSeconds - dt * 0.5)
            end
            e.LastPos = root.Position
            -- zone credit
            for _, z in zones do
                if not z.Closed and playersIn(z, p) then
                    if z.Owner == e.Team and not z.Contested then
                        e.Defense += S.DefendSecond * dt
                        Knit.GetService("MutationService"):DefenseTime(p, dt)
                        e.LifeHoldSeconds += dt
                    elseif z.Owner ~= e.Team or z.Contested then
                        e.Objective += S.CaptureSecond * dt
                        Knit.GetService("MutationService"):NoteObjective(p, S.CaptureSecond * dt)
                        if z.Owner == e.Team then
                            e.LifeHoldSeconds += dt
                        end
                    end
                end
            end
            self:CheckObjectiveBounty(e)
        end
        p:SetAttribute("MatchScore", self:Total(e))
    end
end

function StatsService:OnCapture(zone, playersInside)
    if not match then
        return
    end
    for _, p in playersInside do
        local e = match.Entries[p]
        if e then
            e.Objective += Progression.Score.CapturePoints
            local Mutation = Knit.GetService("MutationService")
            Mutation:NoteObjective(p, Progression.Score.CapturePoints)
            Mutation:AddEnergy(p, "Capture", AlterEgos.Energy.Capture)
            if zone.LastContestedAt and os.clock() - zone.LastContestedAt <= AlterEgos.Energy.ContestedWindow then
                Mutation:AddEnergy(p, "ContestedCapture", AlterEgos.Energy.ContestedCapture)
            end
            e.Captures += 1
            e.LifeCaptures += 1
            self:CheckObjectiveBounty(e)
            if e.Bounty then
                self.Client.Bounty:FireAll(
                    "Ping",
                    { Target = p.Name, Zone = zone.Name, Index = zone.Index, Reason = "capturing" }
                )
            end
        end
    end
end

function StatsService:OnStop(_zone, playersInside)
    if not match then
        return
    end
    for _, p in playersInside do
        local e = match.Entries[p]
        if e then
            e.Defense += Progression.Score.StopPoints
            e.Stops += 1
            self:CheckObjectiveBounty(e)
        end
    end
end

function StatsService:OnDamage(dealer, victimCharacter, amount)
    if not match or not dealer or not victimCharacter then
        return
    end
    local e = match.Entries[dealer]
    if e then
        e.Damage += amount
        e.Combat += amount * Progression.Score.DamagePoint
    end
    local victim = Players:GetPlayerFromCharacter(victimCharacter)
    local ve = victim and match.Entries[victim]
    if ve then
        ve.DamageBy[dealer.UserId] = (ve.DamageBy[dealer.UserId] or 0) + amount
    end
end

function StatsService:OnKill(killer, victim, _victimCharacter)
    if not match then
        return
    end
    local ke = killer and match.Entries[killer]
    local ve = victim and match.Entries[victim]
    match.Kills += 1
    if ke then
        ke.Kills += 1
        ke.LifeKills += 1
        ke.Combat += Progression.Score.KillPoints
        Knit.GetService("MutationService"):OnKill(killer, ve ~= nil and ve.Bounty ~= nil)
        self:CheckCombatBounty(ke)
        if victim then
            ke.PairKills[victim.UserId] = (ke.PairKills[victim.UserId] or 0) + 1
        end
    end
    if ve then
        ve.Deaths += 1
        Knit.GetService("MutationService"):OnDeath(victim)
        -- assists: 25%+ of the victim's max health dealt by someone other than the killer, on this life
        local maxHp = 100
        for dealerId, dmg in ve.DamageBy do
            if dmg >= maxHp * 0.25 and (not killer or dealerId ~= killer.UserId) then
                local assister = Players:GetPlayerByUserId(dealerId)
                local ae = assister and match.Entries[assister]
                if ae then
                    ae.Assists += 1
                    ae.Teamplay += Progression.Score.AssistPoints
                    Knit.GetService("MutationService"):AddEnergy(assister, "Assist", AlterEgos.Energy.Assist)
                end
            end
        end
        -- bounty claim on the victim
        if ve.Bounty then
            self:ClaimBounty(ve, killer, ke)
        end
        ve.LifeKills, ve.LifeCaptures, ve.LifeHoldSeconds, ve.DamageBy = 0, 0, 0, {}
    end
    -- bot victims (victimCharacter with Bot attribute) count for the killer's score only, never for claims
end

-- ===== bounties (match) =====
function StatsService:SetBounty(e, kind, name, xp)
    if e.Bounty and e.Bounty.XP >= xp then
        return
    end
    e.Bounty = { Kind = kind, Name = name, XP = xp, SetAt = now() }
    e.Player:SetAttribute("Bounty", name)
    self.Client.Bounty:FireAll("Set", { Target = e.Player.Name, Name = name, Kind = kind })
end

function StatsService:CheckCombatBounty(e)
    for _, tier in Progression.CombatBounty do
        if e.LifeKills >= tier.Kills then
            self:SetBounty(e, "Combat", tier.Name, tier.XP)
        end
    end
end

function StatsService:CheckObjectiveBounty(e)
    local ob = Progression.ObjectiveBounty
    if
        e.LifeCaptures >= ob.CapturesInOneLife
        or e.LifeHoldSeconds >= ob.HoldSecondsInOneLife
        or e.Stops >= ob.StopsInMatch
    then
        self:SetBounty(e, "Objective", ob.Name, ob.XP)
    end
end

local function eligibleHunter(ke)
    return ke ~= nil and (now() - ke.JoinedAt) >= Progression.Eligibility.MinHunterSeconds
end

function StatsService:ClaimBounty(ve, killer, ke)
    local b = ve.Bounty
    ve.Bounty = nil
    ve.Player:SetAttribute("Bounty", nil)
    local matchAge = now() - match.StartedAt
    local elig = Progression.Eligibility
    local ok = matchAge >= elig.MinMatchSeconds and self:Total(ve) >= elig.MinTargetScore and eligibleHunter(ke)
    local pairIdx = ke and math.min(ke.PairKills[ve.Player.UserId] or 1, #elig.RepeatPairPayouts) or 1
    local mult = ok and elig.RepeatPairPayouts[pairIdx] or 0
    local payout = math.floor(b.XP * mult)
    self.Client.Bounty:FireAll(
        "Claimed",
        { Target = ve.Player.Name, Hunter = killer and killer.Name or "the team", Name = b.Name, XP = payout }
    )
    if payout <= 0 then
        return
    end
    -- team-aware split: team share to eligible opposing teammates, hunter bonus, objective contributors bonus
    local split = Progression.BountySplit
    local hunterTeam = ke and ke.Team or (killer and killer:GetAttribute("Team"))
    local teammates = {}
    for _, e in match.Entries do
        if e.Team == hunterTeam and e.Team ~= ve.Team and eligibleHunter(e) then
            table.insert(teammates, e)
        end
    end
    local teamShare = payout * split.Team / math.max(#teammates, 1)
    for _, e in teammates do
        e.BountyXP = (e.BountyXP or 0) + teamShare
    end
    if ke then
        ke.BountyXP = (ke.BountyXP or 0) + payout * split.Hunter
        ke.BountyClaims = (ke.BountyClaims or 0) + 1
    end
    -- objective contributors: teammates with the highest objective score share the last 15%
    table.sort(teammates, function(a, b2)
        return a.Objective > b2.Objective
    end)
    local top = teammates[1]
    if top then
        top.BountyXP = (top.BountyXP or 0) + payout * split.ObjectiveContributors
    end
end

-- tier-2 approximate pings every BountyPingSeconds: nearest zone name, never a position
function StatsService:PingBounties(zones)
    if not match then
        return
    end
    for p, e in match.Entries do
        if e.Bounty then
            local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local nearest, nd
                for _, z in zones do
                    local d = (z.Position - root.Position).Magnitude
                    if not nd or d < nd then
                        nearest, nd = z, d
                    end
                end
                self.Client.Bounty:FireAll("Ping", {
                    Target = p.Name,
                    Zone = nearest and nearest.Name or "unknown",
                    Index = nearest and nearest.Index,
                    Reason = "near",
                })
            end
        end
    end
end

-- ===== scoreboard =====
function StatsService:BroadcastScoreboard()
    if not match then
        return
    end
    local rows = {}
    for p, e in match.Entries do
        table.insert(rows, {
            Name = p.Name,
            Team = e.Team,
            Score = self:Total(e),
            Kills = e.Kills,
            Deaths = e.Deaths,
            Assists = e.Assists,
            Captures = e.Captures,
            Stops = e.Stops,
            Bounty = e.Bounty and e.Bounty.Name or nil,
            Streak = p:GetAttribute("CurrentStreak") or 0,
        })
    end
    table.sort(rows, function(a, b)
        return a.Score > b.Score
    end)
    self.Client.Scoreboard:FireAll(rows)
end

-- ===== end of match: validation, MVP, streaks, XP, persistent stats, recap =====
local function countsAsPublic()
    local t = tuning()
    if match.Bots then
        return t ~= nil and t:GetAttribute("Debug_CountBotMatches") == true
    end
    return true
end

function StatsService:EndMatch(winnerTeam, aborted)
    if not match then
        return nil
    end
    local duration = now() - match.StartedAt
    local S = Progression.Score
    local valid = not aborted
        and winnerTeam ~= nil
        and duration >= Progression.Eligibility.MinMatchSeconds
        and countsAsPublic()

    -- finish bonus + idle penalty, then MVP by score on the winning team
    local mvp, mvpScore
    for p, e in match.Entries do
        e.Discipline += S.FinishBonus - math.max(0, e.IdleSeconds - 30) * S.IdlePenaltyPerSecond
        local total = self:Total(e)
        p:SetAttribute("MatchScore", total)
        if e.Team == winnerTeam and (not mvpScore or total > mvpScore) then
            mvp, mvpScore = p, total
        end
    end

    for p, e in match.Entries do
        local total = self:Total(e)
        local won = e.Team == winnerTeam
        local recap = {
            Valid = valid,
            Won = won,
            Score = total,
            Breakdown = {
                Objective = math.floor(e.Objective),
                Defense = math.floor(e.Defense),
                Teamplay = math.floor(e.Teamplay),
                Combat = math.floor(e.Combat),
                Discipline = math.floor(e.Discipline),
            },
            Kills = e.Kills,
            Deaths = e.Deaths,
            Assists = e.Assists,
            Captures = e.Captures,
            Stops = e.Stops,
            MVP = mvp and mvp.Name or nil,
            MVPScore = mvpScore,
            IsMVP = p == mvp,
            BountySurvived = false,
            Mutations = p:GetAttribute("MutationActivations") or 0,
            MutantKills = p:GetAttribute("MutantKills") or 0,
            ObjectiveWhileMutated = p:GetAttribute("ObjectiveWhileMutated") or 0,
            BountyClaims = e.BountyClaims or 0,
            XP = 0,
            StreakBefore = p:GetAttribute("CurrentStreak") or 0,
            StreakAfter = 0,
            Checkpoint = nil,
            StatusBefore = nil,
            StatusAfter = nil,
        }
        if valid then
            -- survival: still marked at the end of a won match
            if e.Bounty and won then
                recap.BountySurvived = true
                p:SetAttribute("BountiesSurvived", (p:GetAttribute("BountiesSurvived") or 0) + 1)
                e.BountyXP = (e.BountyXP or 0) + Progression.SurvivalXP
            end
            -- streak (completed public matches only)
            local streak = recap.StreakBefore
            local tierBefore = Progression.streakTier(streak)
            recap.StatusBefore = tierBefore and tierBefore.Name or nil
            if won then
                streak += 1
                for _, cp in Progression.StreakCheckpoints do
                    if streak == cp then
                        recap.Checkpoint = cp
                        local saved = p:GetAttribute("StreakCheckpoints") or ""
                        if not saved:find("%f[%d]" .. cp .. "%f[%D]") then
                            p:SetAttribute("StreakCheckpoints", saved == "" and tostring(cp) or (saved .. "," .. cp))
                        end
                    end
                end
                p:SetAttribute("BestStreak", math.max(p:GetAttribute("BestStreak") or 0, streak))
            else
                streak = 0
            end
            p:SetAttribute("CurrentStreak", streak)
            local tierAfter = Progression.streakTier(streak)
            recap.StreakAfter = streak
            recap.StatusAfter = tierAfter and tierAfter.Name or nil
            p:SetAttribute("StreakStatus", recap.StatusAfter or "")
            -- persistent stats
            local function bump(name, by)
                p:SetAttribute(name, (p:GetAttribute(name) or 0) + by)
            end
            bump("Matches", 1)
            bump(won and "Wins" or "Losses", 1)
            bump("Kills", e.Kills)
            bump("Deaths", e.Deaths)
            bump("Assists", e.Assists)
            bump("Captures", e.Captures)
            bump("ObjectiveScore", math.floor(e.Objective + e.Defense))
            bump("BountiesClaimed", e.BountyClaims or 0)
            if p == mvp then
                bump("MVPs", 1)
            end
            -- XP
            local xp = (won and Progression.XP.Win or Progression.XP.Loss)
                + math.floor(total / Progression.XP.ScoreDivisor)
            if p == mvp then
                xp += Progression.XP.MVP
            end
            xp += math.floor(e.BountyXP or 0)
            recap.XP = xp
            bump("XP", xp)
            p:SetAttribute("Level", Progression.levelForXP(p:GetAttribute("XP") or 0))
        end
        self.Client.Recap:Fire(p, recap)
        p:SetAttribute("Bounty", nil)
    end
    local result = { MVP = mvp, Valid = valid }
    match = nil
    return result
end

function StatsService:Abort()
    if match then
        for p in match.Entries do
            p:SetAttribute("Bounty", nil)
        end
    end
    match = nil
end

return StatsService
