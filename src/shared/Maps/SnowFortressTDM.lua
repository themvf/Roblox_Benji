-- Team Deathmatch uses the approved Snow Fortress arena and baked geometry.
-- Keep mode-specific gameplay data separate so Convergence retains its three objectives.
local fortress = require(script.Parent.SnowFortress)

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in value do
        result[key] = copy(child)
    end
    return result
end

local map = copy(fortress)
map.Name = "SnowFortressTDM"
map.DisplayName = "Snow Fortress"
map.Mode = "TDM"
map.BakedMap = "SnowFortress"
map.Objectives = nil
map.Finale = nil
return map
