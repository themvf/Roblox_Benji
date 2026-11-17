-- Tune the game here, or in Studio: ReplicatedStorage.Tuning attributes override these
-- values at runtime (TuningService creates that Configuration on first run).
local Config = {
    -- Duel (elimination) mode
    IntermissionSeconds = 5, -- countdown after a queue fills, before round 1
    RoundSeconds = 90,
    RoundsToWin = 5,
    RespawnSeconds = 3, -- lobby respawn only; in a Duel you wait for the next round
    Teams = { "Red", "Blue" },
    Maps = { "MyMapPublic" }, -- Duel rotation
    -- Module under Shared/Maps built at server start, before the first match. Also
    -- what Studio's Run (F8) shows, since Run starts the server with no character:
    -- point this at whatever map you are working on to inspect it with a free
    -- camera and no second player. Design default is "Forest".
    --
    -- This one is NOT a Tuning attribute, unlike everything else here. The map builds
    -- once at server start, so a live attribute could not change it anyway, and a saved
    -- one used to beat this line permanently. TuningService clears any it finds.
    StartupMap = "MyMapPublic",

    -- Lobby map vote: once a pad fills, the players on it pick the map before the match starts.
    MapVoteEnabled = true,
    MapVoteSeconds = 12,
    MapVoteOptions = 5, -- candidates offered; capped by how many maps the mode's rotation has

    -- Convergence (featured objective mode). Every number here is a Tuning attribute too.
    ConvergenceMaps = { "MyMapPublic" }, -- the designer-built map (source: assets/environment/source/MyMap.rbxm)
    TDMMaps = { "MyMapTDM" }, -- same arena, no capture objectives
    -- Training pads: one player, bots on both sides. Each team is filled to TeamSize, so the
    -- player's side gets one bot fewer (5 = you + 4 bots against 5 bots). Tuning: Training_TeamSize.
    Training = {
        TeamSize = 5,
    },
    TDM = {
        ScoreToWin = 50,
        RegulationSeconds = 600,
        OvertimeSeconds = 120,
        RespawnSeconds = 3,
        SpawnProtectSeconds = 1,
        RecentHitSeconds = 10,
    },
    Convergence = {
        TeamSize = 1, -- TESTING: design target is 6 (set Convergence_TeamSize in Tuning or here)
        MinTeamSize = 1, -- TESTING: design fallback is 4
        FillWaitSeconds = 30, -- once both sides have MinTeamSize, start after this even if not full
        PhaseSeconds = { 180, 180, 180 }, -- 3 zones -> 2 zones -> 1 zone
        HardCapSeconds = 720, -- 12 min
        OvertimeMaxSeconds = 60,
        ScoreToWin = 1200,
        PointsPerZonePerSecond = 1,
        KillPoints = 5,
        CaptureSeconds = 8, -- solo, neutral -> owned (enemy -> neutral takes the same again)
        StackBonus = 0.5, -- +50% speed per extra teammate in the zone
        MaxStack = 3, -- teammates counted for speed
        ZoneCloseWarningSeconds = 15,
        RespawnSeconds = 3.5,
        SpawnProtectSeconds = 2,
        BotsPerTeam = 5, -- TESTING: one human + five bots per team (chat: /bots N)
    },
}

-- Movement: sprint, crouch, slide (Rivals-style). Exposed as Tuning attributes
-- Movement_<Key>, read live every frame by MovementController. The first three match
-- the Weapons Kit's own speeds, which this replaces (16 walk / 24 sprint / 8 aimed).
Config.Movement = {
    WalkSpeed = 16,
    SprintMultiplier = 1.5, -- hold Shift (PC), click the left stick (controller), auto on touch
    AimMultiplier = 0.5, -- aiming down sights; no sprinting while aimed
    CrouchMultiplier = 0.5, -- hold Ctrl or C (PC), B (controller), CROUCH button (touch)
    SlideSpeed = 42, -- studs/s at the start of a slide; fades to crouch speed
    SlideSeconds = 0.75,
    SlideCooldown = 1.0, -- from the end of one slide to the start of the next
    AutoSprintTouch = true, -- phones/tablets sprint whenever moving, as in Rivals
    AutoSprintDesktop = false, -- Rivals' "Auto Sprint" setting, for keyboard and controller
}

local overrides = nil

-- Walk-up mounted turret. Server reads live Tuning attributes through GetTurret().
Config.Turret = {
    Damage = 8,
    Range = 240,
    FireRate = 8,
    Magazine = 60,
    ReloadSeconds = 4,
    MaxYawDegrees = 75,
    MinPitchDegrees = -18,
    MaxPitchDegrees = 28,
    OperatorDistance = 14,
}

function Config.GetTurret()
    local out = table.clone(Config.Turret)
    if overrides then
        for key, default in Config.Turret do
            local value = overrides:GetAttribute("Turret_" .. key)
            if type(value) == "number" and value == value and value < math.huge and value > -math.huge then
                out[key] = value
            else
                out[key] = default
            end
        end
    end
    out.Damage = math.clamp(out.Damage, 1, 100)
    out.Range = math.clamp(out.Range, 20, 500)
    out.FireRate = math.clamp(out.FireRate, 1, 20)
    out.Magazine = math.floor(math.clamp(out.Magazine, 1, 200))
    out.ReloadSeconds = math.clamp(out.ReloadSeconds, 0.5, 15)
    out.MaxYawDegrees = math.clamp(out.MaxYawDegrees, 10, 180)
    out.MinPitchDegrees = math.clamp(out.MinPitchDegrees, -60, 0)
    out.MaxPitchDegrees = math.clamp(out.MaxPitchDegrees, 0, 60)
    out.OperatorDistance = math.clamp(out.OperatorDistance, 6, 30)
    return out
end

-- Convergence keys exposed as flat Tuning attributes (Convergence_<Key>)
Config.CONVERGENCE_TUNABLE = {
    "TeamSize",
    "MinTeamSize",
    "FillWaitSeconds",
    "HardCapSeconds",
    "OvertimeMaxSeconds",
    "ScoreToWin",
    "PointsPerZonePerSecond",
    "KillPoints",
    "CaptureSeconds",
    "StackBonus",
    "MaxStack",
    "ZoneCloseWarningSeconds",
    "RespawnSeconds",
    "SpawnProtectSeconds",
    "BotsPerTeam",
}

function Config.GetTDM()
    local out = table.clone(Config.TDM)
    if overrides then
        for key, default in Config.TDM do
            local value = overrides:GetAttribute("TDM_" .. key)
            if type(value) == "number" and value == value and value < math.huge and value > 0 then
                out[key] = value
            else
                out[key] = default
            end
        end
    end
    out.ScoreToWin = math.floor(math.clamp(out.ScoreToWin, 1, 500))
    out.RegulationSeconds = math.clamp(out.RegulationSeconds, 30, 3600)
    out.OvertimeSeconds = math.clamp(out.OvertimeSeconds, 10, 600)
    out.RespawnSeconds = math.clamp(out.RespawnSeconds, 0.5, 20)
    out.SpawnProtectSeconds = math.clamp(out.SpawnProtectSeconds, 0.5, 10)
    out.RecentHitSeconds = math.clamp(out.RecentHitSeconds, 1, 60)
    return out
end

-- Training settings with Tuning overrides (Training_<Key>) applied
function Config.GetTraining()
    local out = table.clone(Config.Training)
    local value = overrides and overrides:GetAttribute("Training_TeamSize")
    if type(value) == "number" and value == value and value < math.huge then
        out.TeamSize = value
    end
    out.TeamSize = math.floor(math.clamp(out.TeamSize, 1, 8))
    return out
end

-- Bots each team needs to reach `teamSize`, counting the humans already on it.
function Config.TrainingBots(teamSize, humans)
    return {
        Red = math.max(0, teamSize - (humans.Red or 0)),
        Blue = math.max(0, teamSize - (humans.Blue or 0)),
    }
end

-- Called by TuningService with the Configuration instance; reads are live thereafter.
function Config.SetOverrideSource(inst)
    overrides = inst
end

-- Convergence settings with Tuning overrides applied
function Config.GetConvergence()
    local out = table.clone(Config.Convergence)
    if overrides then
        for _, key in Config.CONVERGENCE_TUNABLE do
            local v = overrides:GetAttribute("Convergence_" .. key)
            if v ~= nil then
                out[key] = v
            end
        end
    end
    -- The first two phases are tunable; the final phase consumes the remaining match cap.
    -- Reject non-finite/invalid phase overrides and reserve at least one second per phase.
    local function positive(value, fallback)
        return type(value) == "number" and value == value and value < math.huge and value > 0 and value or fallback
    end
    out.HardCapSeconds = math.max(3, positive(out.HardCapSeconds, Config.Convergence.HardCapSeconds))
    local first = overrides and overrides:GetAttribute("Convergence_Phase1Seconds")
    local second = overrides and overrides:GetAttribute("Convergence_Phase2Seconds")
    first = math.clamp(positive(first, Config.Convergence.PhaseSeconds[1]), 1, out.HardCapSeconds - 2)
    second = math.clamp(positive(second, Config.Convergence.PhaseSeconds[2]), 1, out.HardCapSeconds - first - 1)
    out.PhaseSeconds = { first, second, out.HardCapSeconds - first - second }
    return out
end

return setmetatable({}, {
    __index = function(_, key)
        if overrides then
            local v = overrides:GetAttribute(key)
            if v ~= nil then
                return v
            end
        end
        return Config[key]
    end,
    __newindex = function(_, key, value)
        Config[key] = value
    end,
})
