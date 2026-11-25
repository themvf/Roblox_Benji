-- Team Deathmatch on Choke Ridge: same natural sandstone T-spur canyon with capture
-- objectives removed and power pickups moved into the cave and southern nose so players
-- must leave sniper perches to contest mid-map control.
local source = require(script.Parent.ChokeRidge)

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
map.Name = "ChokeRidgeTDM"
map.DisplayName = "Choke Ridge (TDM)"
map.Mode = "TDM"
map.Objectives = nil
map.Finale = nil

-- TDM anti-camping pickups: nothing spawns on sniper shelves; high-impact pickups sit
-- on the Southern Nose, inside the Cave, and forward at the cave/nose crossroads.
map.Pickups = {
    { kind = "weapon", weapon = "Minigun", pos = { 0, 1.2, 32 }, respawn = 60, duration = 35 },
    { kind = "weapon", weapon = "Shotgun", pos = { 0, 1.2, 4 }, respawn = 45, duration = 40 },
    {
        kind = "weapon",
        weapon = "WhiteSniper",
        pos = { 0, 1.2, -14 },
        respawnTuning = "WhiteSniperRespawnSeconds",
        respawnOnDeath = true,
    },
    { kind = "jetpack", pos = { -32, 1.2, 10 }, respawn = 45, fuel = 3.5 },
    { kind = "jetpack", pos = { 32, 1.2, 10 }, respawn = 45, fuel = 3.5 },
    { kind = "speed", pos = { -54, 1.2, 6 } },
    { kind = "speed", pos = { 54, 1.2, 6 } },
}

return map
