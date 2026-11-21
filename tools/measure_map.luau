-- Measure a converted map the way a level designer would walk it: how long each team
-- takes to reach each objective, how wide each lane is at its narrowest, whether every
-- choke has a way round, how long the longest view is, and what a vantage point sees.
--
--     lune run tools/measure_map.luau <Name>
--
-- Reads  assets/environment/baked/<Name>.rbxm          the parts the server builds
--        src/shared/Maps/<Name>.lua                    spawns, objectives, bounds
--        assets/environment/source/<Name>.design.luau  optional: lanes, chokes, vantages, targets
-- Writes docs/design/<name>/measure.json               everything below, plus plan data for
--                                                      tools/map_plan.py and the view renderer
--
-- How it measures:
--   Walking   a 2-stud grid. A column of the grid has a floor wherever a solid's top has
--             5 studs of clear space above it; neighbouring floors within 1.5 studs are
--             joined, a drop of up to 24 studs is joined one way. Times assume WalkSpeed
--             16 and no sprint, slide, jump, launch pad or jetpack, so they are upper
--             bounds that are equal for both teams.
--   Seeing    from 4.5 studs above a floor, stepped through the solids one stud at a
--             time. Every collidable part blocks a view, glass included: this is a line
--             of FIRE. Players standing on cover or jumping are not modelled.
--
-- This rules out maps that are broken on paper. It does not say a map is fun.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Validate = require("../src/shared/Maps/Validate")
local MapAuthoring = require("../src/shared/MapAuthoring")
local Convert = require("./mapauthor/convert")

local name = process.args[1]
if not name then
    print("usage: lune run tools/measure_map.luau <Name>")
    process.exit(1)
end
local bakePath = ("assets/environment/baked/%s.rbxm"):format(name)
local mapPath = ("src/shared/Maps/%s.lua"):format(name)
local designPath = ("assets/environment/source/%s.design.luau"):format(name)
local outDir = "docs/design/" .. name:lower()
if not fs.isFile(bakePath) or not fs.isFile(mapPath) then
    print(("%s has no converted map yet; run: bash tools/save_map.sh %s"):format(name, name))
    process.exit(1)
end

local CELL = 2
local CLEAR = 5 -- headroom a floor needs
local STEP = 1.5 -- height two neighbouring floors may differ by and still be walked
local DROP = 24 -- furthest fall treated as a one-way route
local EYE = 4.5
local SPEED = 16

local layout = assert(Convert.loadLua(fs.readFile(mapPath), name))
local roots = roblox.deserializeModel(fs.readFile(bakePath))
local solids = MapAuthoring.solids(roots, Validate)
local design = fs.isFile(designPath) and luau.load(fs.readFile(designPath), { debugName = designPath })() or {}
local M = design.measure or {}
local T = M.targets or {}

-- ===== columns: what is solid, and where the floors are =====
local B = layout.Bounds
local function snap(v)
    return math.floor(v / CELL + 0.5) * CELL
end
local X0, X1 = snap(B.min[1]), snap(B.max[1])
local Z0, Z1 = snap(B.min[3]), snap(B.max[3])
local NX, NZ = (X1 - X0) // CELL + 1, (Z1 - Z0) // CELL + 1

local function colIndex(x, z)
    local i, j = (x - X0) // CELL, (z - Z0) // CELL
    if i < 0 or j < 0 or i >= NX or j >= NZ then
        return nil
    end
    return i * NZ + j + 1
end

local colSpans = table.create(NX * NZ) -- vertical runs of solid on the column's centre line
local colBoxes = table.create(NX * NZ) -- every solid touching the column's square, for exact view tests
for c = 1, NX * NZ do
    colSpans[c] = {}
    colBoxes[c] = {}
end

-- Where a vertical line at (x, z) is inside the box: y0, y1, or nil.
local function verticalSpan(box, x, z)
    local dx, dz = x - box.c.x, z - box.c.z
    local m, h = box.m, { box.h.x, box.h.y, box.h.z }
    local t0, t1 = -math.huge, math.huge
    for i = 1, 3 do
        local a = m[1][i] * dx + m[3][i] * dz
        local b = m[2][i]
        if math.abs(b) < 1e-9 then
            if math.abs(a) > h[i] + 1e-6 then
                return nil
            end
        else
            local lo, hi = (-h[i] - a) / b, (h[i] - a) / b
            if lo > hi then
                lo, hi = hi, lo
            end
            t0, t1 = math.max(t0, lo), math.min(t1, hi)
            if t0 > t1 + 1e-6 then
                return nil
            end
        end
    end
    return box.c.y + t0, box.c.y + t1
end

local function inBox(box, x, y, z)
    local dx, dy, dz = x - box.c.x, y - box.c.y, z - box.c.z
    local m = box.m
    return math.abs(m[1][1] * dx + m[2][1] * dy + m[3][1] * dz) <= box.h.x
        and math.abs(m[1][2] * dx + m[2][2] * dy + m[3][2] * dz) <= box.h.y
        and math.abs(m[1][3] * dx + m[2][3] * dy + m[3][3] * dz) <= box.h.z
end

for bi, box in solids do
    local a = box.aabb
    for x = snap(a.min.x - CELL), snap(a.max.x + CELL), CELL do
        for z = snap(a.min.z - CELL), snap(a.max.z + CELL), CELL do
            local c = colIndex(x, z)
            if c then
                if x + 1 >= a.min.x and x - 1 <= a.max.x and z + 1 >= a.min.z and z - 1 <= a.max.z then
                    table.insert(colBoxes[c], bi)
                end
                local y0, y1 = verticalSpan(box, x, z)
                if y0 then
                    table.insert(colSpans[c], { y0, y1 })
                end
            end
        end
    end
end

-- Nodes: one per floor per column.
local nodes = {} -- { x, y, z, col }
local colNodes = table.create(NX * NZ)
for x = X0, X1, CELL do
    for z = Z0, Z1, CELL do
        local c = colIndex(x, z)
        local list = {}
        for _, span in colSpans[c] do
            local top = span[2]
            if top >= B.min[2] and top <= B.max[2] then
                local free = true
                for _, other in colSpans[c] do
                    if other ~= span and other[2] > top + 0.2 and other[1] < top + CLEAR then
                        free = false
                        break
                    end
                end
                -- several parts can share one top (a rug on a floor): keep one node
                for _, id in list do
                    if math.abs(nodes[id].y - top) < 0.3 then
                        free = false
                    end
                end
                if free then
                    table.insert(nodes, { x = x, y = top, z = z, col = c })
                    table.insert(list, #nodes)
                end
            end
        end
        colNodes[c] = list
    end
end

local function nodeAt(x, y, z)
    local c = colIndex(snap(x), snap(z))
    local best, bestD = nil, math.huge
    for _, id in (c and colNodes[c] or {}) do
        local d = math.abs(nodes[id].y - y)
        if d < bestD then
            best, bestD = id, d
        end
    end
    return best
end

local function openAbove(c, y0, y1)
    for _, span in colSpans[c] do
        if span[2] > y0 + 0.2 and span[1] < y1 then
            return false
        end
    end
    return true
end

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

local function levelNeighbour(n, dx, dz)
    local c = colIndex(n.x + dx * CELL, n.z + dz * CELL)
    for _, id in (c and colNodes[c] or {}) do
        if math.abs(nodes[id].y - n.y) <= STEP then
            return id
        end
    end
    return nil
end

-- Calls visit(neighbourId, cost) for every step out of node `id`.
local function neighbours(id, blocked, visit)
    local n = nodes[id]
    for _, d in DIRS do
        local diagonal = d[1] ~= 0 and d[2] ~= 0
        if not diagonal or (levelNeighbour(n, d[1], 0) and levelNeighbour(n, 0, d[2])) then
            local c = colIndex(n.x + d[1] * CELL, n.z + d[2] * CELL)
            if c and not (blocked and blocked[c]) then
                local length = diagonal and CELL * 1.41421356 or CELL
                for _, other in colNodes[c] do
                    local dy = nodes[other].y - n.y
                    if math.abs(dy) <= STEP then
                        visit(other, math.sqrt(length * length + dy * dy))
                    elseif not diagonal and dy < 0 and -dy <= DROP and openAbove(c, nodes[other].y, n.y + CLEAR) then
                        visit(other, length + -dy * 0.5) -- stepping off a ledge
                    end
                end
            end
        end
    end
end

-- Shortest walking distance from `source` to every node. `blocked` is a set of columns.
local function walk(source, blocked)
    local dist, prev = table.create(#nodes, math.huge), {}
    local heap, size = {}, 0
    local function push(id, d)
        size += 1
        local i = size
        heap[i] = { id, d }
        while i > 1 and heap[i // 2][2] > heap[i][2] do
            heap[i], heap[i // 2] = heap[i // 2], heap[i]
            i //= 2
        end
    end
    local function pop()
        local top = heap[1]
        heap[1] = heap[size]
        heap[size] = nil
        size -= 1
        local i = 1
        while true do
            local l, r, s = i * 2, i * 2 + 1, i
            if l <= size and heap[l][2] < heap[s][2] then
                s = l
            end
            if r <= size and heap[r][2] < heap[s][2] then
                s = r
            end
            if s == i then
                break
            end
            heap[i], heap[s] = heap[s], heap[i]
            i = s
        end
        return top
    end
    dist[source] = 0
    push(source, 0)
    while size > 0 do
        local top = pop()
        local id, d = top[1], top[2]
        if d <= dist[id] then
            neighbours(id, blocked, function(other, cost)
                if d + cost < dist[other] then
                    dist[other] = d + cost
                    prev[other] = id
                    push(other, d + cost)
                end
            end)
        end
    end
    return dist, prev
end

local function pathTo(prev, target)
    local path = {}
    local id = target
    while id do
        table.insert(path, 1, id)
        id = prev[id]
    end
    return path
end

-- ===== seeing =====
local function blockedAt(x, y, z)
    local c = colIndex(snap(x), snap(z))
    if not c then
        return false
    end
    for _, bi in colBoxes[c] do
        if inBox(solids[bi], x, y, z) then
            return true
        end
    end
    return false
end

local function sees(ax, ay, az, bx, by, bz)
    local dx, dy, dz = bx - ax, by - ay, bz - az
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    local steps = math.ceil(length)
    for k = 1, steps - 1 do
        local t = k / steps
        if blockedAt(ax + dx * t, ay + dy * t, az + dz * t) then
            return false
        end
    end
    return true
end

local function nodeSees(a, b)
    return sees(a.x, a.y + EYE, a.z, b.x, b.y + EYE, b.z)
end

-- ===== the map's own points =====
local report, failures, cautions = {}, {}, {}
local function say(line)
    table.insert(report, line)
end
local function verdict(ok, line)
    say(("  %s  %s"):format(ok and "ok  " or "FAIL", line))
    if not ok then
        table.insert(failures, line)
    end
end
local function caution(line)
    say("  note  " .. line)
    table.insert(cautions, line)
end
local function seconds(distance)
    return distance / SPEED
end
local function mirrored(p)
    return { -p[1], p[2], p[3] }
end

local function spawnNode(team)
    local pads = layout.Spawns[team]
    local cx, cz = 0, 0
    for _, p in pads do
        cx += p[1] / #pads
        cz += p[3] / #pads
    end
    local best, bestD = nil, math.huge
    for _, p in pads do
        local d = (p[1] - cx) ^ 2 + (p[3] - cz) ^ 2
        if d < bestD then
            best, bestD = p, d
        end
    end
    return assert(nodeAt(best[1], best[2], best[3]), team .. " spawn is not on a floor the grid can find")
end

local spawn = { Blue = spawnNode("Blue"), Red = spawnNode("Red") }
local fromSpawn = { Blue = { walk(spawn.Blue) }, Red = { walk(spawn.Red) } }
local objectiveNode = {}
for _, o in layout.Objectives do
    objectiveNode[o.Id] = assert(nodeAt(o.pos[1], o.pos[2], o.pos[3]), "objective " .. o.Id .. " is not on a floor")
end

local result = {
    map = name,
    revision = layout.Revision,
    cell = CELL,
    speed = SPEED,
    lanes = {},
    chokes = {},
    sightlines = {},
    vantages = {},
}

-- ===== 1. travel and balance =====
say(("%s  %s  (%d solids, %d floor cells)"):format(name, tostring(layout.Revision), #solids, #nodes))
say("")
say("Travel from spawn, walking at 16 studs/s")
result.travel = {}
local nearest = math.huge
for _, o in layout.Objectives do
    local blue = seconds(fromSpawn.Blue[1][objectiveNode[o.Id]])
    local red = seconds(fromSpawn.Red[1][objectiveNode[o.Id]])
    result.travel[o.Id] = { blue = blue, red = red }
    nearest = math.min(nearest, blue, red)
    local limit = T.balance or 0.5
    verdict(
        blue < math.huge and red < math.huge and math.abs(blue - red) <= limit,
        ("%s (%s): Blue %.1f s, Red %.1f s"):format(o.Id, o.Name or o.Id, blue, red)
    )
end
if T.firstObjective then
    verdict(
        nearest >= T.firstObjective[1] and nearest <= T.firstObjective[2],
        ("nearest objective is %.1f s from spawn (target %g-%g s)"):format(
            nearest,
            T.firstObjective[1],
            T.firstObjective[2]
        )
    )
end
local enemy = seconds(fromSpawn.Blue[1][spawn.Red])
say(("  spawn to spawn: %.1f s"):format(enemy))
result.spawnToSpawn = enemy

-- ===== 2. lanes =====
-- Free cells in a straight line through a node, in studs; the smallest of four directions
-- is how wide the passage is there.
local function widthAt(id)
    local n = nodes[id]
    local narrowest = math.huge
    for _, d in { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } } do
        local run = 1
        for _, sign in { 1, -1 } do
            local k = 1
            while k < 40 do
                local c = colIndex(n.x + d[1] * sign * k * CELL, n.z + d[2] * sign * k * CELL)
                local found = false
                for _, other in (c and colNodes[c] or {}) do
                    if math.abs(nodes[other].y - n.y) <= STEP * k then
                        found = true
                    end
                end
                if not found then
                    break
                end
                run += 1
                k += 1
            end
        end
        local scale = (d[1] ~= 0 and d[2] ~= 0) and CELL * 1.41421356 or CELL
        -- a solid face on a grid line blocks that line's column, so the true gap is one cell wider
        narrowest = math.min(narrowest, (run + 1) * scale)
    end
    return narrowest
end

if M.lanes then
    say("")
    say("Lanes (Blue side; Red's are the mirror image)")
    for _, lane in M.lanes do
        local stops = { spawn.Blue }
        for _, p in lane.via do
            -- not table.insert(stops, assert(...)): assert returns its message too, and a
            -- three-argument insert treats the node id as a position
            local stop = nodeAt(p[1], p[2], p[3])
            assert(stop, lane.name .. ": a waypoint is not on a floor")
            table.insert(stops, stop)
        end
        table.insert(stops, objectiveNode[lane.objective])
        local total, cells = 0, {}
        for i = 1, #stops - 1 do
            local dist, prev = walk(stops[i])
            total += dist[stops[i + 1]]
            for _, id in pathTo(prev, stops[i + 1]) do
                table.insert(cells, id)
            end
        end
        local narrow, narrowAt = math.huge, nil
        for _, id in cells do
            local w = widthAt(id)
            if w < narrow then
                narrow, narrowAt = w, id
            end
        end
        local line = {}
        for i = 1, #cells, 3 do
            table.insert(line, { nodes[cells[i]].x, nodes[cells[i]].z })
        end
        table.insert(result.lanes, {
            name = lane.name,
            objective = lane.objective,
            seconds = seconds(total),
            narrowest = narrow,
            narrowestAt = narrowAt and { nodes[narrowAt].x, nodes[narrowAt].y, nodes[narrowAt].z },
            path = line,
        })
        verdict(
            total < math.huge and narrow >= (T.minLaneWidth or 8),
            ("%s: %.1f s to %s, narrowest %.0f studs at (%d, %d)"):format(
                lane.name,
                seconds(total),
                lane.objective,
                narrow,
                narrowAt and nodes[narrowAt].x or 0,
                narrowAt and nodes[narrowAt].z or 0
            )
        )
    end
end

-- ===== 3. chokes =====
local function columnsIn(region)
    local set = {}
    for x = snap(region.min[1]), snap(region.max[1]), CELL do
        for z = snap(region.min[2]), snap(region.max[2]), CELL do
            local c = colIndex(x, z)
            if c then
                set[c] = true
            end
        end
    end
    return set
end

if M.chokes then
    say("")
    say("Chokes: the cost of going round each one when it is held (Blue side)")
    for _, choke in M.chokes do
        local set = columnsIn(choke)
        local dist = walk(spawn.Blue, set)
        local worst, worstId, used = 1, nil, {}
        for _, o in layout.Objectives do
            local direct, _ = fromSpawn.Blue[1][objectiveNode[o.Id]], nil
            local onRoute = false
            for _, id in pathTo(fromSpawn.Blue[2], objectiveNode[o.Id]) do
                if set[nodes[id].col] then
                    onRoute = true
                    break
                end
            end
            if onRoute then
                table.insert(used, o.Id)
                local ratio = dist[objectiveNode[o.Id]] / direct
                if ratio > worst then
                    worst, worstId = ratio, o.Id
                end
            end
        end
        table.insert(result.chokes, {
            name = choke.name,
            region = { choke.min, choke.max },
            onRouteTo = used,
            detour = worst < math.huge and worst or -1,
        })
        if #used == 0 then
            say(("  --    %s: not on a shortest route from spawn; an alternative, not a choke"):format(choke.name))
        elseif worst == math.huge then
            verdict(
                false,
                ("%s: no way round it to %s. A held choke would lock the objective out"):format(choke.name, worstId)
            )
        else
            verdict(
                worst <= (T.maxChokeDetour or 2.5),
                ("%s: on the route to %s; going round costs %.2fx"):format(choke.name, table.concat(used, ", "), worst)
            )
        end
    end
end

-- ===== 4. sightlines =====
say("")
say("Lines of fire (eye height, every collidable part blocks)")
local reachable = {}
for id, n in nodes do
    if fromSpawn.Blue[1][id] < math.huge and n.x % 8 == 0 and n.z % 8 == 0 then
        table.insert(reachable, id)
    end
end
local longest = {}
for i = 1, #reachable do
    local a = nodes[reachable[i]]
    for j = i + 1, #reachable do
        local b = nodes[reachable[j]]
        local d2 = (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2
        if d2 > 60 * 60 and nodeSees(a, b) then
            table.insert(longest, { math.sqrt(d2), a, b })
        end
    end
end
table.sort(longest, function(p, q)
    return p[1] > q[1]
end)
local limit = T.maxSightline or 120
local over = 0
for _, s in longest do
    if s[1] > limit then
        over += 1
    end
end
if #longest > 0 then
    verdict(
        longest[1][1] <= limit,
        ("longest is %.0f studs, (%d, %d) to (%d, %d); %d sampled pairs over the %d-stud target"):format(
            longest[1][1],
            longest[1][2].x,
            longest[1][2].z,
            longest[1][3].x,
            longest[1][3].z,
            over,
            limit
        )
    )
else
    say("  ok    no line of fire longer than 60 studs")
end
for i = 1, math.min(12, #longest) do
    local s = longest[i]
    table.insert(
        result.sightlines,
        { length = s[1], from = { s[2].x, s[2].y, s[2].z }, to = { s[3].x, s[3].y, s[3].z } }
    )
end

-- spawn protection
local function padEyes(team)
    local eyes = {}
    for _, p in layout.Spawns[team] do
        table.insert(eyes, { p[1], p[2] + EYE, p[3] })
    end
    return eyes
end
local spawnSeesSpawn = false
for _, a in padEyes("Blue") do
    for _, b in padEyes("Red") do
        if sees(a[1], a[2], a[3], b[1], b[2], b[3]) then
            spawnSeesSpawn = true
        end
    end
end
verdict(not spawnSeesSpawn, "no spawn pad can see an enemy spawn pad")
for _, o in layout.Objectives do
    local seen = false
    for _, a in padEyes("Blue") do
        if sees(a[1], a[2], a[3], o.pos[1], o.pos[2] + EYE, o.pos[3]) then
            seen = true
        end
    end
    verdict(not seen, ("no spawn pad can see objective %s"):format(o.Id))
end
-- From how far away can a spawn pad be shot?
local farthest, farthestFrom = 0, nil
for _, id in reachable do
    local n = nodes[id]
    for _, a in padEyes("Blue") do
        local d = math.sqrt((a[1] - n.x) ^ 2 + (a[3] - n.z) ^ 2)
        if d > farthest and sees(a[1], a[2], a[3], n.x, n.y + EYE, n.z) then
            farthest, farthestFrom = d, n
        end
    end
end
result.spawnExposure =
    { distance = farthest, from = farthestFrom and { farthestFrom.x, farthestFrom.y, farthestFrom.z } }
verdict(
    farthest <= (T.spawnExposure or 70),
    ("a Blue spawn pad can be shot from up to %.0f studs away, at (%d, %d)"):format(
        farthest,
        farthestFrom and farthestFrom.x or 0,
        farthestFrom and farthestFrom.z or 0
    )
)

-- ===== 5. vantage points =====
if M.vantages then
    say("")
    say("Vantage points")
    for _, v in M.vantages do
        local id = assert(nodeAt(v.at[1], v.at[2], v.at[3]), v.name .. " is not on a floor")
        local n = nodes[id]
        local entry = { name = v.name, at = v.at, approaches = {}, seesObjectives = {} }
        local alive = 0
        for _, approach in v.approaches or {} do
            local dist = walk(spawn.Blue, columnsIn(approach))
            local open = dist[id] < math.huge
            alive += open and 1 or 0
            table.insert(
                entry.approaches,
                { name = approach.name, reachableWithout = open, seconds = open and seconds(dist[id]) or -1 }
            )
        end
        verdict(
            #(v.approaches or {}) >= 2 and alive == #v.approaches,
            ("%s: %.1f s from spawn; still reachable with any one of its %d approaches held"):format(
                v.name,
                seconds(fromSpawn.Blue[1][id]),
                #(v.approaches or {})
            )
        )
        -- A player on a balcony steps to the rail to look down, so test every floor cell
        -- of the vantage within 8 studs of its marker, not the marker alone.
        local stand = {}
        for other, q in nodes do
            if
                math.abs(q.y - n.y) <= STEP
                and (q.x - n.x) ^ 2 + (q.z - n.z) ^ 2 <= 64
                and fromSpawn.Blue[1][other] < math.huge
            then
                table.insert(stand, q)
            end
        end
        for _, o in layout.Objectives do
            for _, q in stand do
                if sees(q.x, q.y + EYE, q.z, o.pos[1], o.pos[2] + EYE, o.pos[3]) then
                    table.insert(entry.seesObjectives, o.Id)
                    break
                end
            end
        end
        verdict(
            #entry.seesObjectives < #layout.Objectives,
            ("%s sees objective(s): %s"):format(
                v.name,
                #entry.seesObjectives > 0 and table.concat(entry.seesObjectives, ", ") or "none"
            )
        )
        local exposed = 0
        for _, other in reachable do
            if other ~= id and math.abs(nodes[other].y - n.y) > 3 and nodeSees(nodes[other], n) then
                exposed += 1
            end
        end
        local twin = nodeAt(-v.at[1], v.at[2], v.at[3])
        entry.exposedFrom = exposed
        entry.seesTwin = twin ~= nil and nodeSees(n, nodes[twin])
        verdict(
            exposed > 0,
            ("%s can be shot from %d sampled floor positions on other levels%s"):format(
                v.name,
                exposed,
                entry.seesTwin and ", and from the enemy's matching vantage" or ""
            )
        )
        table.insert(result.vantages, entry)
    end
end

caution("times ignore sprint, slide, jump, launch pads and jetpacks; views ignore players standing on cover")
caution("glass is treated as blocking fire; confirm against how the Weapons Kit handles Glass parts")

-- ===== plan data =====
result.bounds = { min = B.min, max = B.max }
result.spawns = layout.Spawns
result.objectives = {}
for _, o in layout.Objectives do
    table.insert(result.objectives, { id = o.Id, name = o.Name, pos = o.pos, radius = o.radius })
end
result.floors = {}
for id, n in nodes do
    if fromSpawn.Blue[1][id] < math.huge then
        table.insert(result.floors, { n.x, n.z, math.floor(n.y * 10 + 0.5) / 10 })
    end
end
result.parts = {}
local function collect(inst)
    if inst:IsA("BasePart") then
        local cf, size, color = inst.CFrame, inst.Size, inst.Color
        local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
        local okCollide, collide = pcall(function()
            return inst.CanCollide
        end)
        local okT, transparency = pcall(function()
            return inst.Transparency
        end)
        local okM, material = pcall(function()
            return inst.Material.Name
        end)
        table.insert(result.parts, {
            name = inst.Name,
            pos = { x, y, z },
            size = { size.X, size.Y, size.Z },
            rot = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
            color = { color.R, color.G, color.B },
            transparency = okT and transparency or 0,
            material = okM and material or "SmoothPlastic",
            collide = okCollide and collide or false,
        })
    end
    for _, child in inst:GetChildren() do
        collect(child)
    end
end
for _, r in roots do
    collect(r)
end
-- Props, for the preview renderer: where each stands, and the file on disk that was uploaded.
result.props = {}
local glbById = {}
for _, asset in design.assets or {} do
    if asset.glb then
        if asset.id then
            glbById[asset.id] = asset.glb
        end
        if asset.registry then
            glbById[asset.registry] = asset.glb
        end
    end
end
for _, piece in layout.Decor or {} do
    if piece.kind == "prop" then
        table.insert(result.props, {
            name = piece.name,
            pos = piece.pos,
            yaw = piece.rot and piece.rot[2] or 0,
            fit = piece.fit,
            glb = glbById[piece.asset or piece.assetId],
        })
    end
end
-- Props that are built but not uploaded yet: the game leaves their blocks visible, the
-- preview draws the model and hides the block, so the art can be judged before upload.
result.hidden = {}
local pendingPath = outDir .. "/props-not-uploaded.json"
if fs.isFile(pendingPath) then
    for _, prop in serde.decode("json", fs.readFile(pendingPath)) do
        prop.notUploaded = true
        table.insert(result.props, prop)
        if prop.hides then
            table.insert(result.hidden, prop.hides)
        end
    end
end
result.views = M.views or {}
result.targets = T
result.failures = failures
result.cautions = cautions

if not fs.isDir(outDir) then
    fs.writeDir(outDir)
end
fs.writeFile(outDir .. "/measure.json", serde.encode("json", result))

say("")
say(
    #failures == 0 and ("%s: all measured targets met."):format(name)
        or ("%s: %d measured target(s) missed."):format(name, #failures)
)
say("wrote " .. outDir .. "/measure.json")
print(table.concat(report, "\n"))
process.exit(#failures == 0 and 0 or 1)
