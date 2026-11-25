-- Highway Overpass TDM: Team Deathmatch variant of HighwayOverpass.
local source = require(script.Parent.HighwayOverpass)

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

local map = copy(source)
map.Name = "HighwayOverpassTDM"
map.DisplayName = "Highway Overpass (TDM)"
map.Mode = "TDM"
map.Objectives = nil
map.Finale = nil
map.BakedMap = source.Name

return map
