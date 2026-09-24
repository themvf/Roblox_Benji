-- Build gate: a map that has given up its geometry must actually have a bake.
--
-- This used to compare a bake against the builder that produced it. That comparison died
-- with the builder: Snow Fortress no longer describes any parts, so "every source solid is
-- present" became "all 0 source solids present" -- a gate passing loudly while checking
-- nothing, which is the failure mode this project keeps tripping over.
--
-- What is worth asserting now is narrow and real. A layout that declares RequiresBake has
-- no geometry of its own, so a missing or empty bake means an empty world, and
-- MapService refuses to build it. Catch that here rather than in a play session.
--
-- There is no part-count floor. It used to be 50, which failed every honest starter
-- map (one floor slab and markers) while proving nothing about a big one. What
-- matters is that something is collidable and no authoring scaffolding ships.
--
-- A map converted from an editable source (tools/map.luau) is also regenerated here
-- and compared with what is committed: a failed conversion, a source saved without
-- converting, or a hand edit to the generated files all fail the build.
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
local Authoring = require("./mapauthor/convert")

local MAPS_DIR = "src/shared/Maps"
local SKIP = { ["Validate.lua"] = true, ["Lobby.lua"] = true }

-- Authoring scaffolding: the old GUIDE kit piece by name (it predates attributes), and
-- anything from the template by attribute. Both are translucent and non-collidable, so a
-- map carrying one looks completely normal until somebody asks what the glowing cylinder is.
local GUIDE_NAMES = { "^GUIDE$", "^Bound_[XZ]", "^Objective_[ABC]", "^Centre$", "^Centre_Pole$", "^Spawn_[BR]" }
local function isScaffolding(inst)
    if inst:GetAttribute("AuthoringHelper") ~= nil or inst:GetAttribute("Role") ~= nil then
        return true
    end
    for _, pattern in GUIDE_NAMES do
        if inst.Name:match(pattern) then
            return true
        end
    end
    return false
end

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
                elseif #solids == 0 and not (layout.Terrain and not layout.Terrain.Sea) then
                    failures += 1
                    print(("FAIL  %-14s baked with nothing collidable and no terrain -- nothing to stand on"):format(name))
                else
                    local leftovers = {}
                    for _, root in roblox.deserializeModel(fs.readFile(Baked.path(name))) do
                        for _, inst in root:GetDescendants() do
                            if isScaffolding(inst) then
                                table.insert(leftovers, inst.Name)
                            end
                        end
                    end
                    local stale = layout.Authored and Authoring.freshness(".", name) or {}
                    if #stale > 0 then
                        failures += 1
                        print(("FAIL  %-14s generated files do not match the editable source:"):format(name))
                        for _, problem in stale do
                            print("        " .. problem)
                        end
                        print(("        run: bash tools/save_map.sh %s"):format(name))
                    elseif #leftovers > 0 then
                        failures += 1
                        print(("FAIL  %-14s %d guide markers left in the bake, e.g. %s"):format(
                            name,
                            #leftovers,
                            leftovers[1]
                        ))
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
