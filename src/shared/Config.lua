-- Tune the game here, or in Studio: ReplicatedStorage.Tuning attributes override these
-- values at runtime (TuningService creates that Configuration on first run).
local Config = {
    -- Duel (elimination) mode
    IntermissionSeconds = 5, -- countdown after a queue fills, before round 1
    RoundSeconds = 90,
    RoundsToWin = 5,
    RespawnSeconds = 3, -- lobby respawn only; in a Duel you wait for the next round
    Teams = { "Red", "Blue" },
    Maps = { "Forest", "Snow", "Arena" }, -- Duel rotation

    -- Convergence (featured objective mode). Every number here is a Tuning attribute too.
    ConvergenceMaps = { "Carrier", "Forest", "Snow" },
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
        BotsPerTeam = 0, -- test bots per team (chat: /bots N)
    },
}

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

local overrides = nil

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
