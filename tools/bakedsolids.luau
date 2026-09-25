-- Turn a baked map into the box list Validate understands, plus a flat part list for
-- gates that assert on named pieces.
--
-- A baked map has no piece descriptions, only parts. That is the point: the parts are
-- what the server actually creates, including collision the layout never described --
-- the facade kit alone authors 282 of them, and no gate has ever seen those.
--
-- Collidable is the whole test for a solid. An invisible wall still stops a launched
-- player, and this map is full of them: greybox blocks hidden behind facade meshes.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local MapAuthoring = require("../src/shared/MapAuthoring")

local M = {}

M.DIR = "assets/environment/baked"

function M.path(mapName)
    for _, ext in { ".rbxm", ".rbxmx" } do
        local candidate = M.DIR .. "/" .. mapName .. ext
        if fs.isFile(candidate) then
            return candidate
        end
    end
    return nil
end

-- Returns solids (Validate box list) and parts ({name, pos, size, collide}), or nil.
function M.load(mapName, Validate)
    local path = M.path(mapName)
    if not path then
        return nil, nil
    end
    return M.fromRoots(roblox.deserializeModel(fs.readFile(path)), Validate)
end

-- The same, for instances already in memory: the map converter checks its candidate
-- bake before it is written anywhere, so it cannot go through a path on disk.
function M.fromRoots(roots, Validate)
    return MapAuthoring.solids(roots, Validate)
end

return M
