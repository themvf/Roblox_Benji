-- Team Deathmatch on MyMap: the public release's arena, spawns and bake, with the
-- capture objectives removed so Convergence keeps its three zones.
local public = require(script.Parent.MyMapPublic)

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

local map = copy(public)
map.Name = "MyMapTDM"
map.Mode = "TDM"
map.Objectives = nil
map.Finale = nil
return map
