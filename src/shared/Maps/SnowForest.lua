-- Public Team Deathmatch map: the existing Snow (winter Forest) terrain and
-- cover, without Convergence capture objectives. Five humans spawn per side;
-- the sixth authored spawn remains available as a safe respawn alternative.
local Snow = require(script.Parent.Snow)

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

local map = copy(Snow)
map.Name = "SnowForest"
map.DisplayName = "Snow Forest"
map.Mode = "TDM"
map.Objectives = nil
map.Finale = nil
return map
