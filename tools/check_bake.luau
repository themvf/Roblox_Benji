-- Build gate: a map that has given up its geometry must actually have a bake.
--
-- This used to compare a bake against the builder that produced it. That comparison died
-- with the builder: Snow Fortress no longer describes any parts, so "every source solid is
-- present" became "all 0 source solids present" -- a gate passing loudly while checking
-- nothing, which is the failure mode this project keeps tripping over.
--
-- What is worth asserting now is narrow and real. A layout that declares RequiresBake has
-- no geometry of its own, so a missing or nearly-empty bake means an empty world, and
-- MapService refuses to build it. Catch that here rather than in a play session.
--
-- The geometry itself is checked where it is used: check_maps traces launch arcs against
-- the baked parts, and check_fortress_layout asserts on them directly.
--
--     lune run tools/check_bake.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local Validate = require("../src/shared/Maps/Validate")
local Baked = require("./bakedsolids")

local MAPS_DIR = "src/shared/Maps"
local SKIP = { ["Validate.lua"] = true, ["Lobby.lua"] = true }
-- A bake with almost nothing in it is a failed save, not a small map.
local MIN_PARTS = 50

-- Derived maps (Snow) require their base by instance path; give them a `script` to walk.
local preloaded = { Forest = require("../src/shared/Maps/Forest") }
script = { Parent = preloaded }
local luneRequire = require
require = function(target)
    if type(target) == "table" then
        return target
    end
    return luneRequire(target)
end

local checked, failures = 0, 0
local files = fs.readDir(MAPS_DIR)
table.sort(files)

for _, file in files do
    if file:sub(-4) == ".lua" and not SKIP[file] then
        local ok, layout = pcall(luneRequire, "../" .. MAPS_DIR .. "/" .. file:sub(1, -5))
        if ok then
            local name = layout.Name or file:sub(1, -5)
            local solids, parts = Baked.load(name, Validate)

            if layout.RequiresBake then
                checked += 1
                if not parts then
                    failures += 1
                    print(("FAIL  %-14s declares RequiresBake but %s/%s.rbxm is missing"):format(name, Baked.DIR, name))
                elseif #parts < MIN_PARTS then
                    failures += 1
                    print(("FAIL  %-14s baked with only %d parts -- that is a failed save"):format(name, #parts))
                else
                    print(("OK    %-14s %d parts baked, %d of them collidable"):format(name, #parts, #solids))
                end
            elseif parts then
                -- Baked but still building from its layout: harmless, and worth saying out
                -- loud, because the bake is not what the server is running.
                print(("note  %-14s has a bake (%d parts) but does not declare RequiresBake"):format(name, #parts))
            end
        end
    end
end

if checked == 0 then
    print("no maps require a bake")
    process.exit(0)
end
print(("\n%d baked maps checked, %d failed"):format(checked, failures))
if failures > 0 then
    process.exit(1)
end
