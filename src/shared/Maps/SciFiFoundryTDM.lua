-- Team Deathmatch on Sector-M9 (SciFiFoundry): uses the Studio-editable baked
-- geometry from assets/environment/source/SciFiFoundry.rbxm with objectives removed
-- and Grav-Lift LaunchPads wired for TDM.
local foundry = require(script.Parent.SciFiFoundry)

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

local map = copy(foundry)
map.Name = "SciFiFoundryTDM"
map.DisplayName = "Sector-M9: Sci-Fi Foundry"
map.Mode = "TDM"
map.BakedMap = "SciFiFoundry"
map.Draft = nil
map.Authored = nil
map.Objectives = nil
map.Finale = nil
map.LaunchPads = {
    { pos = { -50, 0.1, -46 }, target = { -36, 11.7, -72 }, vy = 70, size = 8 },
    { pos = { 50, 0.1, -46 }, target = { 36, 11.7, -72 }, vy = 70, size = 8 },
    { pos = { -52, 0.1, 85 }, target = { -42, 11.7, 100.0 }, vy = 70, size = 8 },
    { pos = { 52, 0.1, 85 }, target = { 42, 11.7, 100.0 }, vy = 70, size = 8 },
}
return map
