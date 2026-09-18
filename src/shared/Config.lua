-- Tune the game here, or in Studio: ReplicatedStorage.Tuning attributes override these
-- values at runtime (TuningService creates that Configuration on first run).
local Config = {
    IntermissionSeconds = 5, -- countdown after a queue fills, before round 1
    RoundSeconds = 90,
    RoundsToWin = 5,
    RespawnSeconds = 3, -- lobby respawn only; in a match you wait for the next round
    Teams = { "Red", "Blue" },
    Maps = { "Forest", "Snow", "Arena" }, -- one is picked at random per match (never the same twice in a row)
}

local overrides = nil

-- Called by TuningService with the Configuration instance; reads are live thereafter.
function Config.SetOverrideSource(inst)
    overrides = inst
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
