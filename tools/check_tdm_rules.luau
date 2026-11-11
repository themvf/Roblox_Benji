local rules = require("../src/shared/TDMRules")

local function expect(score, target, expired, overtime, action, winner)
    local actualAction, actualWinner = rules.decision(score, target, expired, overtime)
    assert(actualAction == action, ("expected %s, got %s"):format(action, actualAction))
    assert(actualWinner == winner, ("expected winner %s, got %s"):format(tostring(winner), tostring(actualWinner)))
end

expect({ Red = 49, Blue = 48 }, 50, false, false, "continue", nil)
expect({ Red = 50, Blue = 48 }, 50, false, false, "win", "Red")
expect({ Red = 50, Blue = 50 }, 50, false, false, "continue", nil)
expect({ Red = 42, Blue = 41 }, 50, true, false, "win", "Red")
expect({ Red = 42, Blue = 42 }, 50, true, false, "overtime", nil)
expect({ Red = 51, Blue = 50 }, 50, false, true, "continue", nil)
expect({ Red = 51, Blue = 50 }, 50, true, true, "win", "Red")
expect({ Red = 50, Blue = 50 }, 50, true, true, "win", nil) -- draw
print("TDM score and overtime rules passed")
