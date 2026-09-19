-- Competitive loop data: match score weights, streak tiers, bounty tiers, XP and level.
-- Pure data + math so both server and client can read it. Rewards are XP, titles and cosmetics only.
local Progression = {}

-- ===== Match score (transparent MVP) =====
-- Objective 40% · Defense 20% · Teamplay 20% · Combat 15% · Discipline 5%
Progression.Score = {
    CapturePoints = 120, -- per capture the player was inside for
    CaptureSecond = 2, -- per second inside a zone being captured / held while contested
    StopPoints = 60, -- per enemy capture neutralized while inside
    DefendSecond = 1, -- per second inside an owned zone
    AssistPoints = 35, -- 25%+ damage on a victim killed by a teammate
    KillPoints = 40,
    DamagePoint = 0.1, -- per damage dealt
    FinishBonus = 50, -- completed the match
    IdlePenaltyPerSecond = 1, -- seconds with no movement beyond 30 s
}

-- ===== Streaks (completed public matches) =====
Progression.StreakTiers = {
    { Wins = 2, Name = "Heating Up", Prestige = 0 },
    { Wins = 3, Name = "Hot Streak", Prestige = 1 },
    { Wins = 5, Name = "On Fire", Prestige = 2 },
    { Wins = 8, Name = "Elite Streak", Prestige = 3 },
    { Wins = 10, Name = "Legendary", Prestige = 4 },
    { Wins = 15, Name = "Mythic", Prestige = 5 },
}
Progression.StreakCheckpoints = { 3, 5, 8, 10 } -- saved forever as legacy badges

function Progression.streakTier(wins)
    local best
    for _, t in Progression.StreakTiers do
        if wins >= t.Wins then
            best = t
        end
    end
    return best
end

-- ===== Match bounties (Phase 2: XP + titles only) =====
Progression.CombatBounty = {
    { Kills = 4, Name = "Marked", XP = 60 },
    { Kills = 7, Name = "Priority Target", XP = 120 },
    { Kills = 10, Name = "Overrun", XP = 200 },
}
Progression.ObjectiveBounty = {
    Name = "Objective Specialist",
    XP = 150,
    CapturesInOneLife = 2,
    HoldSecondsInOneLife = 90,
    StopsInMatch = 3,
}
-- team-aware payout of a claimed bounty's XP
Progression.BountySplit = { Team = 0.60, Hunter = 0.25, ObjectiveContributors = 0.15 }
Progression.BountyPingSeconds = 75 -- tier-2 approximate zone ping
Progression.SurvivalXP = 80 -- target survives to a won match while marked

-- ===== Eligibility (anti-abuse, server side) =====
Progression.Eligibility = {
    MinMatchSeconds = 90,
    MinTargetScore = 100, -- target must have contributed
    MinHunterSeconds = 60, -- hunter must have been in the match this long
    RepeatPairPayouts = { 1.0, 0.5, 0.0 }, -- same hunter -> same target within a match
}

-- ===== XP / level =====
Progression.XP = { Win = 100, Loss = 50, ScoreDivisor = 10, MVP = 75 }

function Progression.levelForXP(xp)
    return math.floor(math.sqrt(math.max(xp, 0) / 100)) + 1
end

function Progression.xpForLevel(level)
    return (level - 1) ^ 2 * 100
end

-- ===== Convergence Rating (featured board) =====
-- L = 0.40 WQ + 0.25 OC + 0.20 M + 0.10 BS + 0.05 BC, each term normalised per match
function Progression.rating(stats)
    local matches = math.max(stats.Matches or 0, 1)
    local winRate = (stats.Wins or 0) / matches
    local objPerMatch = (stats.ObjectiveScore or 0) / matches / 400 -- ~400 objective points = strong match
    local mvpRate = (stats.MVPs or 0) / matches
    local survive = (stats.BountiesSurvived or 0) / matches
    local claims = (stats.BountiesClaimed or 0) / matches
    local l = 0.40 * winRate
        + 0.25 * math.min(objPerMatch, 1)
        + 0.20 * mvpRate
        + 0.10 * math.min(survive, 1)
        + 0.05 * math.min(claims, 1)
    -- scale by a confidence factor so 2 matches cannot top the board
    local confidence = math.min(matches / 10, 1)
    return math.floor(l * 1000 * confidence)
end

return Progression
