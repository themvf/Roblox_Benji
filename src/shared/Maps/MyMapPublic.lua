-- The public objective-mode release of MyMap. Hand-written; MyMap.lua itself is generated.
--
-- Generated maps are drafts (looser fairness rules) and check_maps keeps drafts out of
-- every rotation. This wrapper is the promotion: the same layout and bake with Draft
-- cleared, so Validate holds it to the full rules. To change the map, edit the source in
-- Studio and run `bash tools/save_map.sh MyMap`; this file picks the change up.
local source = require(script.Parent.MyMap)

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
map.Name = "MyMapPublic"
map.DisplayName = "Snow Fortress"
map.BakedMap = source.Name
map.Draft = nil
map.Authored = nil -- generated-file drift checks belong to MyMap.lua, not this wrapper
-- The active Snow Fortress arena. TDM copies this wrapper, so both modes use the
-- same two creator-movable markers while keeping generated MyMap.lua untouched.
map.Pickups = {
    {
        kind = "weapon",
        weapon = "WhiteSniper",
        marker = "BlueOutpost",
        pos = { -90, 1.596, -145 },
        respawnTuning = "WhiteSniperRespawnSeconds",
        respawnOnDeath = true,
    },
    {
        kind = "weapon",
        weapon = "WhiteSniper",
        marker = "RedOutpost",
        pos = { 90, 1.596, -145 },
        respawnTuning = "WhiteSniperRespawnSeconds",
        respawnOnDeath = true,
    },
}
return map
