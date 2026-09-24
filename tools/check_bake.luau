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
-- What tells a failed save apart from a map that is simply new is the FLOOR. A save that
-- went wrong loses everything, ground included; a map being built has barely anything on
-- it yet but is always standing on something. So the rule is coverage, not a part count.
--
-- This used to be "at least 50 parts", which is true of every finished map and false of
-- every map on its first day -- it would have rejected the starter bake the repo now ships
-- as the way to begin. A detailed map that floors itself with tiles instead of one slab
-- passes on the part count instead, so neither shape is locked out.
local MIN_PARTS = 50
local FLOOR_COVERAGE = 0.6

-- Largest horizontal footprint among the collidable parts, as a share of the map's own
-- bounds. One slab answers this directly; a tiled floor answers it on the part count.
local function floorShare(parts, bounds)
    if not (bounds and bounds.min and bounds.max) then
        return 1
    end
    local spanX = math.abs(bounds.max[1] - bounds.min[1])
    local spanZ = math.abs(bounds.max[3] - bounds.min[3])
    if spanX <= 0 or spanZ <= 0 then
        return 1
    end
    local best = 0
    for _, part in parts do
        if part.collide then
            best = math.max(best, math.min(part.size[1] / spanX, part.size[3] / spanZ))
        end
    end
    return best
end

-- The guide is scaffolding: bounds, objective circles, spawn pads, a centre pole. It is
-- meant to be deleted before saving, and it is exactly the kind of thing that gets left
-- in -- it is translucent and non-collidable, so a map carrying one looks completely
-- normal until somebody wonders what the glowing cylinder is.
local GUIDE_NAMES = { "^GUIDE$", "^Bound_[XZ]", "^Objective_[ABC]", "^Centre_Pole$", "^Spawn_[BR]" }

-- Derived maps (Snow) require their base by instance path; give them a `script` to walk.
local preloaded = {}
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
                elseif #parts < MIN_PARTS and floorShare(parts, layout.Bounds) < FLOOR_COVERAGE then
                    failures += 1
                    print(
                        ("FAIL  %-14s baked with %d parts and no floor covering %d%% of its "):format(
                            name,
                            #parts,
                            FLOOR_COVERAGE * 100
                        ) .. "bounds -- that is a failed save, not a small map"
                    )
                else
                    local leftovers = {}
                    for _, part in parts do
                        for _, pattern in GUIDE_NAMES do
                            if part.name:match(pattern) then
                                table.insert(leftovers, part.name)
                                break
                            end
                        end
                    end
                    if #leftovers > 0 then
                        failures += 1
                        print(
                            ("FAIL  %-14s %d guide markers left in the bake, e.g. %s"):format(
                                name,
                                #leftovers,
                                leftovers[1]
                            )
                        )
                    else
                        print(("OK    %-14s %d parts baked, %d of them collidable"):format(name, #parts, #solids))
                    end
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
