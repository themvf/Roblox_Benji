local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum

local art = require("../src/shared/MapArt/AlpineFortress")
script = { Parent = { Parent = { MapArt = { AlpineFortress = art } } } }
local luneRequire = require
require = function(target)
    if type(target) == "table" then
        return target
    end
    return luneRequire(target)
end

local map = require("../src/shared/Maps/SnowFortress")

-- Art may change surface treatment but must not add gameplay collision.
for _, piece in map.Center do
    if piece.name:match("^Art") and piece.kind == "block" then
        assert(piece.decor == true, "entrance trim must not collide or intercept weapon queries")
    end
end

local function distance2(a, b)
    local dx, dz = a[1] - b[1], a[3] - b[3]
    return math.sqrt(dx * dx + dz * dz)
end

local function assertPointInBounds(point, label)
    local minimum, maximum = map.Bounds.min, map.Bounds.max
    assert(point[1] >= minimum[1] and point[1] <= maximum[1], label .. " x outside bounds")
    assert(point[2] >= minimum[2] and point[2] <= maximum[2], label .. " y outside bounds")
    assert(point[3] >= minimum[3] and point[3] <= maximum[3], label .. " z outside bounds")
end

assert(map.Name == "SnowFortress")
assert(map.SafetyAlwaysOn == true, "fortress safety must not depend on debug visualization")
assert(#map.Spawns.Red == 6 and #map.Spawns.Blue == 6, "each team needs six exterior spawns")

local redX, blueX = 0, 0
for index, red in map.Spawns.Red do
    local blue = map.Spawns.Blue[index]
    redX += red[1]
    blueX += blue[1]
    assert(red[1] == -blue[1] and red[2] == blue[2] and red[3] == blue[3], "spawn pairs must be symmetric")
    assertPointInBounds(red, "Red spawn")
    assertPointInBounds(blue, "Blue spawn")
end
redX /= #map.Spawns.Red
blueX /= #map.Spawns.Blue
assert(blueX < -180 and redX > 180 and redX - blueX >= 400, "Blue west, Red east exterior starts")

assert(#map.Objectives == 3, "fortress requires three districts")
local objectives = {}
for _, objective in map.Objectives do
    assert(not objectives[objective.Id], "duplicate objective ID")
    assert(objective.halfHeight and objective.halfHeight > 0, "objective needs explicit vertical membership")
    objectives[objective.Id] = objective
    assertPointInBounds(objective.pos, objective.Name)
end
for index = 1, #map.Objectives do
    for other = index + 1, #map.Objectives do
        local a, b = map.Objectives[index], map.Objectives[other]
        assert(
            distance2(a.pos, b.pos) - a.radius - b.radius >= 70,
            "district capture areas are not meaningfully separated"
        )
    end
end
local a, b, c = map.Objectives[1].pos, map.Objectives[2].pos, map.Objectives[3].pos
assert(a[1] == 0 and b[1] == 0 and c[1] == 0, "A/C/B share the sketch's north-south axis")
assert(a[3] < -90 and b[3] > 90 and c[3] == 0, "A/B exterior, C central")

assert(#map.SniperOutposts == 2, "v1 requires exactly two outposts")
assert(#map.LaunchPads == 4, "sketch requires four launch approaches")
assert(#map.ZipLines == 2, "sketch requires two diagonal zips")
assert(#map.GrappleAnchors == 0, "do not invent extra traversal routes")
assert(map.SniperOutposts[1].pos[1] < 0 and map.SniperOutposts[1].pos[3] < 0, "northwest outpost")
assert(map.SniperOutposts[2].pos[1] > 0 and map.SniperOutposts[2].pos[3] > 0, "southeast outpost")
assert(#map.SafePoints >= 5, "recovery points must be spread across the battlefield")
assert(#map.Barrier == 4, "outer boundary must enclose all four sides")

local routes = {}
local routesPerDistrict = {}
local routeKinds = {}
for _, route in map.GroundRoutes do
    assert(type(route.Id) == "string" and route.Id ~= "", "ground route needs a stable ID")
    assert(not routes[route.Id], "duplicate ground route ID")
    assert(objectives[route.DistrictId], "ground route references an unknown district")
    assert(
        route.From and route.To and route.Waypoints and #route.Waypoints >= 2,
        "ground route needs endpoints and waypoints"
    )
    routes[route.Id] = route
    routesPerDistrict[route.DistrictId] = (routesPerDistrict[route.DistrictId] or 0) + 1
    routeKinds[route.Kind] = true
    for _, point in route.Waypoints do
        assertPointInBounds(point, route.Id)
    end
end
for districtId in objectives do
    assert((routesPerDistrict[districtId] or 0) >= 2, districtId .. " needs at least two independent ground approaches")
end
assert(routeKinds.direct and routeKinds.covered, "route inventory needs ordinary direct and covered approaches")

local function checkAlternative(record, label)
    assert(type(record.Id) == "string" and record.Id ~= "", label .. " needs a stable ID")
    assert(routes[record.GroundAlternative or record.GroundRouteId], label .. " needs a valid ground alternative")
end

for _, outpost in map.SniperOutposts do
    checkAlternative(outpost, "outpost")
    assertPointInBounds(outpost.pos, outpost.Id)
end
for _, pad in map.LaunchPads do
    checkAlternative(pad, "launch pad")
    assertPointInBounds(pad.pos, pad.Id .. " origin")
    assertPointInBounds(pad.target, pad.Id .. " landing")
    assert(distance2(pad.pos, pad.target) >= 45, "launch pad route is too short to justify mobility")
    for _, objective in map.Objectives do
        assert(distance2(pad.target, objective.pos) > objective.radius + 8, "launch pad lands in an objective")
    end
end
for _, line in map.ZipLines do
    checkAlternative(line, "zip line")
    assert(line.From and line.To and line.Purpose, "zip line needs endpoints and purpose")
    assertPointInBounds(line.From, line.Id .. " origin")
    assertPointInBounds(line.To, line.Id .. " landing")
    assert(line.To[2] >= 21, "zip must reach second story")
    assert(line.From[1] * line.From[3] < 0, "zip must start southwest or northeast")
end
for _, anchor in map.GrappleAnchors do
    checkAlternative(anchor, "grapple anchor")
    assert(anchor.From and anchor.To and anchor.Purpose, "grapple anchor needs endpoints and purpose")
    assertPointInBounds(anchor.From, anchor.Id .. " origin")
    assertPointInBounds(anchor.To, anchor.Id .. " destination")
end

-- Check actual authored block geometry, not just declarative route counts.
local function clearBody(point, label)
    for _, piece in map.Center do
        if piece.kind ~= "block" or piece.rot then
            continue
        end
        local overlaps = true
        for axis = 1, 3 do
            local margin = 2
            if math.abs(point[axis] - piece.pos[axis]) >= piece.size[axis] / 2 + margin then
                overlaps = false
                break
            end
        end
        assert(not overlaps, label .. " intersects " .. piece.name)
    end
end
for _, line in map.ZipLines do
    for sample = 0, 40 do
        local point = {}
        for axis = 1, 3 do
            point[axis] = line.From[axis] + (line.To[axis] - line.From[axis]) * sample / 40
        end
        clearBody(point, line.Id)
    end
end
for _, pad in map.LaunchPads do
    local duration = (pad.vy + math.sqrt(pad.vy * pad.vy - 2 * 196.2 * (pad.target[2] - 4))) / 196.2
    for sample = 0, 40 do
        local fraction = sample / 40
        local t = duration * fraction
        clearBody({
            pad.pos[1] + (pad.target[1] - pad.pos[1]) * fraction,
            4 + pad.vy * t - 196.2 * t * t / 2,
            pad.pos[3] + (pad.target[3] - pad.pos[3]) * fraction,
        }, pad.Id)
    end
end
assert(map.Objectives[3].pos[1] == 0, "keep must not favor an exterior spawn")

-- The upper slab covers the entire fortress except the two authored stair slots.
local function upperFloorAt(x, z)
    for _, piece in map.Center do
        if
            piece.kind == "block"
            and piece.pos[2] == 17.5
            and piece.size[2] == 1
            and math.abs(x - piece.pos[1]) <= piece.size[1] / 2
            and math.abs(z - piece.pos[3]) <= piece.size[3] / 2
        then
            return true
        end
    end
    return false
end
for x = -69.5, 69.5 do
    for z = -54.5, 54.5 do
        local stairHole = (x > 33 and x < 47 and z > 1 and z < 37) or (x > -47 and x < -33 and z > -37 and z < -1)
        assert(upperFloorAt(x, z) == not stairHole, "upper floor coverage or stair opening incorrect")
    end
end
for _, piece in map.Center do
    if
        piece.name:match("^UpperStair")
        or piece.name:match("^northwestStair")
        or piece.name:match("^southeastStair")
    then
        clearBody({ piece.pos[1], piece.pos[2] + piece.size[2] / 2 + 3, piece.pos[3] }, piece.name .. " head clearance")
    end
end
local c = map.Objectives[3]
assert(math.abs(21 - c.pos[2]) <= c.halfHeight, "upper floor must capture C")
assert(math.abs(7 - c.pos[2]) > c.halfHeight, "ground floor must not capture C through the ceiling")
for _, post in map.SniperOutposts do
    assert(post.pos[2] == 19 and upperFloorAt(post.pos[1], post.pos[3]), "outpost must have an upper deck at 18")
end

local Validate = require("../src/shared/Maps/Validate")
assert(Validate.check(map), "full map validator must accept authored topology")
map.Symmetry.SniperOutposts = "x"
assert(not Validate.check(map), "diagonal outposts must not silently pass x-mirror validation")
map.Symmetry.SniperOutposts = "rotational"
local original = map.SniperOutposts[2].pos[3]
map.SniperOutposts[2].pos[3] += 10
assert(not Validate.check(map), "rotational symmetry still requires a matching partner")
map.SniperOutposts[2].pos[3] = original
assert(Validate.check(map), "restore valid map after negative cases")
for _, key in
    {
        "ClockTime",
        "Brightness",
        "Ambient",
        "OutdoorAmbient",
        "FogColor",
        "FogStart",
        "FogEnd",
        "Atmosphere",
        "SunRays",
        "Bloom",
    }
do
    assert(map.Environment[key] ~= nil, "MapService lighting requires " .. key)
end
assert(map.Terrain.GroundMaterial == Enum.Material.Snow, "alpine exterior uses terrain-compatible snow")
assert(#map.ReviewViews == 12, "retain standardized review camera positions for manual testing")

print(
    "PASS: sketch topology, Blue west/Red east, A/C/B, diagonal outposts, four launches, two upper zips; sampled traversal clears solids"
)
