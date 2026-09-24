-- Build gate: audits Studio-authored decor against the routes it cannot see.
--
-- Decor is arranged in Studio and saved to assets/environment/decor/<Map>.rbxmx. That is
-- the point of it -- no coordinate goes through a source file and no change needs review.
-- But a designer in the viewport cannot see a zip cable's flight path or a launch arc, and
-- a part left collidable under one of them stops a player mid-route.
--
-- So: non-collidable decor is nobody's business and is not checked. Collidable decor has
-- to clear the traversal routes of the map it belongs to.
--
--     lune run tools/check_decor.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Map data uses these as globals. Lune has no Roblox globals, so publish them first.
Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local DECOR_DIR = "assets/environment/decor"
local MARGIN = 6 -- studs of clearance beyond the part's own half-extent

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

-- Distance from a point to a line segment.
local function pointToSegment(p, a, b)
    local v = b - a
    local w = p - a
    local len = v:Dot(v)
    local t = len > 0 and math.clamp(w:Dot(v) / len, 0, 1) or 0
    return (w - v * t).Magnitude
end

local function v3(t)
    return Vector3.new(t[1], t[2], t[3])
end

-- Every route a player travels through open air on this map.
local function routes(layout)
    local out = {}
    for _, zip in layout.ZipLines or {} do
        table.insert(out, { kind = "zip line", id = zip.Id, from = v3(zip.From), to = v3(zip.To) })
    end
    for i, pad in layout.LaunchPads or {} do
        -- A launch arc bows upward, so the straight line from pad to target is the closest
        -- it ever comes to the ground. Measuring against that flags early, which is right.
        table.insert(out, { kind = "launch pad", id = pad.Id or tostring(i), from = v3(pad.pos), to = v3(pad.target) })
    end
    return out
end

local failures = 0
local checked = 0

if not fs.isDir(DECOR_DIR) then
    print("no " .. DECOR_DIR .. " directory; nothing to check")
    process.exit(0)
end

for _, file in fs.readDir(DECOR_DIR) do
    if not file:match("%.rbxmx$") then
        continue
    end
    local mapName = file:sub(1, -7)
    local ok, layout = pcall(luneRequire, "../src/shared/Maps/" .. mapName)
    if not ok then
        print(("SKIP  %s -- no map module named %s"):format(file, mapName))
        continue
    end

    local roots = roblox.deserializeModel(fs.readFile(DECOR_DIR .. "/" .. file))
    local lanes = routes(layout)
    local solid, problems = 0, {}
    for _, root in roots do
        for _, d in root:GetDescendants() do
            if d:IsA("BasePart") and d.CanCollide then
                solid += 1
                local half = math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2
                for _, lane in lanes do
                    local gap = pointToSegment(d.Position, lane.from, lane.to) - half
                    if gap < MARGIN then
                        table.insert(
                            problems,
                            ("%s is collidable and %.0f studs from %s %s (needs %d)"):format(
                                d:GetFullName(),
                                gap,
                                lane.kind,
                                lane.id,
                                MARGIN
                            )
                        )
                    end
                end
            end
        end
    end

    checked += 1
    if #problems > 0 then
        failures += 1
        print(("FAIL  %s  %d collidable parts"):format(file, solid))
        for _, problem in problems do
            print("        " .. problem)
        end
    else
        print(("OK    %-22s %d collidable parts, %d routes"):format(file, solid, #lanes))
    end
end

print(("\n%d decor files checked, %d failed"):format(checked, failures))
if failures > 0 then
    process.exit(1)
end
