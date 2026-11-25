-- Pure Team Deathmatch clock/score decisions, shared with the local rule gate.
local TDMRules = {}

local function leader(score)
    if score.Red > score.Blue then
        return "Red"
    elseif score.Blue > score.Red then
        return "Blue"
    end
    return nil
end

-- Returns "continue", "win", or "overtime" and an optional winning team.
-- Overtime always consumes its full clock, even if a side passes the target.
function TDMRules.decision(score, target, expired, overtime)
    if overtime then
        return expired and "win" or "continue", expired and leader(score) or nil
    end
    if expired then
        local winner = leader(score)
        return winner and "win" or "overtime", winner
    end
    if score.Red >= target or score.Blue >= target then
        local winner = leader(score)
        if winner then
            return "win", winner
        end
    end
    return "continue", nil
end

return TDMRules
