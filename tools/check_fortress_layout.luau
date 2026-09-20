local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum

local map = require("../src/shared/Maps/SnowFortress")

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
assert(redX < -180 and blueX > 180 and blueX - redX >= 400, "spawns must be opposite exterior starts")

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
local twiceTriangleArea = math.abs((b[1] - a[1]) * (c[3] - a[3]) - (c[1] - a[1]) * (b[3] - a[3]))
assert(twiceTriangleArea >= 5000, "districts must form a spatial triangle")

assert(#map.SniperOutposts == 2, "v1 requires exactly two outposts")
assert(#map.LaunchPads == 2, "v1 requires exactly two launch pads")
assert(#map.ZipLines == 4, "v1 requires four zip-line route records")
assert(#map.GrappleAnchors == 4, "initial blockout requires four grapple route records")
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
assert(
    routeKinds.direct and routeKinds.covered and routeKinds.sheltered,
    "route inventory needs direct, covered, and sheltered choices"
)

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
        if piece.kind ~= "block" or piece.rot or piece.size[2] <= 1 then
            continue
        end
        local overlaps = true
        for axis = 1, 3 do
            local margin = axis == 2 and 2 or 2
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
    local duration = 2 * pad.vy / 196.2
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

print(
    "PASS: symmetric exterior spawns, triangular districts, bounds/safety, 12 ground routes, "
        .. "2 outposts, 2 launch pads, 4 zip lines, and 4 grapple anchors"
)
