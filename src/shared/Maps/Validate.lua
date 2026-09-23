-- Map validator: the Map Builder Plugin spec's VALIDATE MAP section as code, plus the
-- geometry rules from the roblox-map-building skill. Pure Luau, no Roblox APIs, so it runs
-- in Lune at build time (tools/check_maps.luau) and in the game at runtime.
--
-- The rule that drives most of this: MapService places `Center` once and `Mirrored` twice,
-- at x and -x with rot.y and rot.z negated. Any gameplay list that is meant to be fair must
-- pair on that SAME x-mirror. Authoring a pair by 180-degree rotation instead (mirroring x
-- and z) silently puts one team's object somewhere the other team's geometry is not.
local Validate = {}

-- kinds placePiece understands; `solid` = it collides, so it blocks a launch arc
-- `solid` = it collides, so it blocks a launch arc. `sized` = placePiece reads piece.size.
Validate.KINDS = {
    block = { solid = true, sized = true },
    rock = { solid = true, sized = true },
    log = { solid = true, sized = true },
    stump = { solid = true, sized = true },
    grove = { solid = false, sized = true }, -- random scatter; trunks collide but positions are seeded
    marker = { solid = false, sized = true },
    light = { solid = false, sized = false },
    beacon = { solid = false, sized = false },
    elevator = { solid = true, sized = true },
    jet = { solid = true, sized = false },
    helicopter = { solid = true, sized = false },
    steam = { solid = false, sized = false },
    radar = { solid = false, sized = false },
    -- A Creator Store model placed by asset id. Decor by default, and `solid = false`
    -- describes that default: it is somebody else's mesh, so no gate can audit its
    -- shape. A piece may set `collide = true` to opt into real collision, and that is
    -- a reviewed exception -- the arc tracer still will not see it, so keep a
    -- collidable prop away from launch lanes and put a block there if it must be cover.
    prop = { solid = false, sized = false, asset = true },
}

-- Composite props, copied from MapService.placePiece. Offsets are local to the piece's
-- position and yaw (rot[2] only). Keep in step with MapService when a prop changes.
local PROP_PARTS = {
    jet = {
        { "Fuselage", { 0, 2.2, 0 }, { 4, 3, 22 } },
        { "Nose", { 0, 2.2, -13 }, { 2.5, 2.2, 5 } },
        { "WingL", { -8, 1.8, 2 }, { 12, 0.5, 8 } },
        { "WingR", { 8, 1.8, 2 }, { 12, 0.5, 8 } },
        { "Tail", { 0, 5, 9 }, { 0.5, 5, 5 } },
        { "Canopy", { 0, 4.2, -5 }, { 2.4, 1.4, 5 } },
        { "Gear1", { 0, 0.6, -8 }, { 0.6, 1.4, 0.6 } },
        { "Gear2", { -2, 0.6, 3 }, { 0.6, 1.4, 0.6 } },
        { "Gear3", { 2, 0.6, 3 }, { 0.6, 1.4, 0.6 } },
    },
    helicopter = {
        { "Cabin", { 0, 3, 0 }, { 5, 4, 12 } },
        { "Tail", { 0, 3.5, 11 }, { 1.2, 1.4, 12 } },
        { "TailFin", { 0, 5.5, 16 }, { 0.4, 3, 2 } },
        { "Skid1", { -2, 0.6, 0 }, { 0.4, 0.4, 10 } },
        { "Skid2", { 2, 0.6, 0 }, { 0.4, 0.4, 10 } },
        { "Canopy", { 0, 4, -4.5 }, { 4, 2.4, 3 } },
        { "RotorA", { 0, 5.6, 0 }, { 22, 0.15, 1 } },
        { "Rotor2", { 0, 5.6, 0 }, { 1, 0.15, 22 } },
    },
}

-- Thresholds. The skill's numbers where it has them, conservative guesses where it does not.
Validate.RULES = {
    SpawnsPerTeam = 6,
    SpawnSpacingMin = 6, -- pads are 6x6; closer than this and MapService's occupancy check blurs two pads
    LaunchVyMin = 55,
    LaunchVyMax = 70,
    ArcClearError = 2.5, -- character root passes this close to a solid = it clips
    ArcClearWarn = 5.0,
    LandingDrop = 2.5, -- landing point must be this close above a floor
    PadRadius = 8, -- takeoff / landing footprint excluded from the arc clearance test
    FlyOver = 3, -- a solid this far below the player's root is flown over, not hit
    RampAngleMax = 32, -- steeper stalls characters
    RampAngleMin = 20,
    MirrorEpsilon = 0.51, -- paired entries may differ by rounding, not by design
    SafePointsMin = 5,
    DropHeight = 8, -- a map with a fall this big needs safety data
    Gravity = 196.2,
}

local R = Validate.RULES

-- ===== small vector / box helpers (plain tables, no Roblox datatypes) =====

local function vec(t)
    return { x = t[1], y = t[2], z = t[3] }
end

local function sub(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

-- Rotation matrix for CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz, degrees in.
local function basis(rot)
    local rx, ry, rz = math.rad(rot[1] or 0), math.rad(rot[2] or 0), math.rad(rot[3] or 0)
    local cx, sx = math.cos(rx), math.sin(rx)
    local cy, sy = math.cos(ry), math.sin(ry)
    local cz, sz = math.cos(rz), math.sin(rz)
    -- columns of Rx*Ry*Rz
    return {
        { cy * cz, -cy * sz, sy },
        { sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy },
        { -cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy },
    }
end

-- Distance from a world point to an oriented box (0 when inside).
local function pointToBox(p, box)
    local d = sub(p, box.c)
    local m = box.m
    local lx = m[1][1] * d.x + m[2][1] * d.y + m[3][1] * d.z
    local ly = m[1][2] * d.x + m[2][2] * d.y + m[3][2] * d.z
    local lz = m[1][3] * d.x + m[2][3] * d.y + m[3][3] * d.z
    local ox = math.max(0, math.abs(lx) - box.h.x)
    local oy = math.max(0, math.abs(ly) - box.h.y)
    local oz = math.max(0, math.abs(lz) - box.h.z)
    return math.sqrt(ox * ox + oy * oy + oz * oz)
end

-- World-space AABB of an oriented box, for cheap footprint tests.
local function boxAabb(box)
    local m, h = box.m, box.h
    local ex = math.abs(m[1][1]) * h.x + math.abs(m[1][2]) * h.y + math.abs(m[1][3]) * h.z
    local ey = math.abs(m[2][1]) * h.x + math.abs(m[2][2]) * h.y + math.abs(m[2][3]) * h.z
    local ez = math.abs(m[3][1]) * h.x + math.abs(m[3][2]) * h.y + math.abs(m[3][3]) * h.z
    return {
        min = { x = box.c.x - ex, y = box.c.y - ey, z = box.c.z - ez },
        max = { x = box.c.x + ex, y = box.c.y + ey, z = box.c.z + ez },
    }
end

local function makeBox(name, pos, size, rot)
    local box = {
        name = name,
        c = vec(pos),
        h = { x = size[1] / 2, y = size[2] / 2, z = size[3] / 2 },
        m = basis(rot or { 0, 0, 0 }),
    }
    box.aabb = boxAabb(box)
    return box
end

local function mirrorPos(p)
    return { -p[1], p[2], p[3] }
end

local function mirrorRot(r)
    if not r then
        return nil
    end
    return { r[1], -r[2], -r[3] }
end

local function samePos(a, b, eps)
    return math.abs(a[1] - b[1]) <= eps and math.abs(a[2] - b[2]) <= eps and math.abs(a[3] - b[3]) <= eps
end

local function fmt(p)
    return ("(%g, %g, %g)"):format(p[1], p[2], p[3])
end

-- ===== geometry model: every solid the builder will place =====

-- One piece -> the boxes MapService creates for it, already in world space.
local function pieceBoxes(out, piece, mirrored)
    local kind = piece.kind or "block"
    local spec = Validate.KINDS[kind]
    if not spec or not spec.solid then
        return
    end
    local pos = mirrored and mirrorPos(piece.pos) or piece.pos
    local rot = mirrored and mirrorRot(piece.rot) or piece.rot
    local name = (mirrored and "Blue_" or "") .. (piece.name or kind)
    local size = piece.size

    if kind == "block" or kind == "elevator" then
        -- an elevator also occupies everything down to `low`; model it at deck level
        table.insert(out, makeBox(name, pos, size, rot))
    elseif kind == "rock" then
        -- base block plus two random lumps; pad the base to cover them
        local s = { size[1] * 1.15, size[2] * 1.15, size[3] * 1.15 }
        table.insert(out, makeBox(name, { pos[1], pos[2] + size[2] / 2, pos[3] }, s, rot))
    elseif kind == "log" then
        local r = rot or { 0, 0, 0 }
        table.insert(
            out,
            makeBox(name, { pos[1], pos[2] + size[2] / 2, pos[3] }, { size[3], size[2], size[2] }, {
                r[1],
                r[2] + 90,
                r[3],
            })
        )
    elseif kind == "stump" then
        table.insert(
            out,
            makeBox(name, { pos[1], pos[2] + size[2] / 2, pos[3] }, { size[2], size[1], size[3] }, { 0, 0, 90 })
        )
    elseif PROP_PARTS[kind] then
        local yaw = (rot and rot[2]) or 0
        local a = math.rad(yaw)
        local ca, sa = math.cos(a), math.sin(a)
        for _, part in PROP_PARTS[kind] do
            local off, psize = part[2], part[3]
            -- the prop is built from a base CFrame with yaw only
            local wx = pos[1] + off[1] * ca + off[3] * sa
            local wz = pos[3] - off[1] * sa + off[3] * ca
            table.insert(out, makeBox(name .. "/" .. part[1], { wx, pos[2] + off[2], wz }, psize, { 0, yaw, 0 }))
        end
    end
end

-- Every solid box in the built map, mirrored copies included.
function Validate.solids(layout)
    local out = {}
    for _, piece in layout.Center or {} do
        pieceBoxes(out, piece, false)
    end
    for _, piece in layout.Mirrored or {} do
        pieceBoxes(out, piece, false)
        pieceBoxes(out, piece, true)
    end
    return out
end

-- Every piece that can carry `collide`, wherever it was authored. Props moved to the
-- Decor list, and a rule that only read Center would have gone quiet without failing.
local function decorAndCentre(layout)
    local all = {}
    for _, piece in layout.Center or {} do
        table.insert(all, piece)
    end
    for _, piece in layout.Decor or {} do
        table.insert(all, piece)
    end
    return all
end

-- Distance from a point to a line segment, all in world space. Used to keep collidable
-- props off the traversal routes, where the thing being avoided is a path rather than a box.
local function pointToSegment(p, a, b)
    local vx, vy, vz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    local wx, wy, wz = p[1] - a[1], p[2] - a[2], p[3] - a[3]
    local len = vx * vx + vy * vy + vz * vz
    local t = len > 0 and math.clamp((wx * vx + wy * vy + wz * vz) / len, 0, 1) or 0
    local dx, dy, dz = wx - t * vx, wy - t * vy, wz - t * vz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- ===== launch arcs (PickupService.launchVelocity, replayed) =====

function Validate.arc(from, to, vy)
    local dy = to[2] - from[2]
    local disc = vy * vy - 2 * R.Gravity * dy
    if disc < 0 then
        vy = math.sqrt(2 * R.Gravity * dy) + 12
        disc = vy * vy - 2 * R.Gravity * dy
    end
    local flight = (vy + math.sqrt(disc)) / R.Gravity
    return flight, vy
end

-- Closest a launched player's root gets to any solid in transit, and what it was.
-- Two things are not obstacles and are excluded: the floors at either end (samples within
-- PadRadius of takeoff or landing), and anything the player clears overhead (a solid whose
-- top is more than FlyOver below the root, which is the deck for most of a flat arc).
local function arcClearance(from, to, vy, solids, samples)
    local flight = Validate.arc(from, to, vy)
    local best, bestBox, bestAt, bestT = math.huge, nil, nil, 0
    for i = 0, samples do
        local t = flight * i / samples
        local p = {
            x = from[1] + (to[1] - from[1]) * t / flight,
            y = from[2] + vy * t - 0.5 * R.Gravity * t * t,
            z = from[3] + (to[3] - from[3]) * t / flight,
        }
        local dFrom = math.sqrt((p.x - from[1]) ^ 2 + (p.z - from[3]) ^ 2)
        local dTo = math.sqrt((p.x - to[1]) ^ 2 + (p.z - to[3]) ^ 2)
        if dFrom < R.PadRadius or dTo < R.PadRadius then
            continue
        end
        for _, box in solids do
            -- cheap reject before the exact test
            local a = box.aabb
            if
                p.y - a.max.y < R.FlyOver
                and p.x > a.min.x - best
                and p.x < a.max.x + best
                and p.y > a.min.y - best
                and p.y < a.max.y + best
                and p.z > a.min.z - best
                and p.z < a.max.z + best
            then
                local d = pointToBox(p, box)
                if d < best then
                    best, bestBox, bestAt, bestT = d, box, { p.x, p.y, p.z }, t
                end
            end
        end
    end
    return best, bestBox, bestAt, bestT
end

-- Highest solid top under an xz point, for "is there floor here" tests.
local function floorUnder(solids, pos)
    local top = nil
    for _, box in solids do
        local a = box.aabb
        if pos[1] >= a.min.x and pos[1] <= a.max.x and pos[3] >= a.min.z and pos[3] <= a.max.z then
            if a.max.y <= pos[2] + 0.75 and (top == nil or a.max.y > top) then
                top = a.max.y
            end
        end
    end
    return top
end

-- ===== checks =====

local function inBounds(layout, p)
    local b = layout.Bounds
    if not b then
        return true
    end
    return p[1] >= b.min[1]
        and p[1] <= b.max[1]
        and p[2] >= b.min[2]
        and p[2] <= b.max[2]
        and p[3] >= b.min[3]
        and p[3] <= b.max[3]
end

local function inBox(p, box)
    return math.abs(p[1] - box.pos[1]) <= box.size[1] / 2
        and math.abs(p[2] - box.pos[2]) <= box.size[2] / 2
        and math.abs(p[3] - box.pos[3]) <= box.size[3] / 2
end

-- Every entry in a list that is meant to be team-fair needs an x-mirror partner.
-- Entries on the centre line (x ~ 0) are their own partner.
local function checkMirrored(errors, label, list, getPos, symmetry)
    if symmetry ~= nil and symmetry ~= "x" and symmetry ~= "rotational" then
        table.insert(errors, label .. ": unsupported symmetry " .. tostring(symmetry))
        return
    end
    for i, entry in list or {} do
        local pos = getPos(entry)
        if math.abs(pos[1]) > R.MirrorEpsilon or (symmetry == "rotational" and math.abs(pos[3]) > R.MirrorEpsilon) then
            local want = mirrorPos(pos)
            if symmetry == "rotational" then
                want[3] = -pos[3]
            end
            local found = false
            for j, other in list do
                if j ~= i and samePos(getPos(other), want, R.MirrorEpsilon) then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(
                    errors,
                    ("%s[%d] at %s has no %s partner at %s"):format(
                        label,
                        i,
                        fmt(pos),
                        symmetry or "x-mirror",
                        fmt(want)
                    )
                )
            end
        end
    end
end

function Validate.check(layout, weapons)
    local errors, warnings = {}, {}
    local info = { Solids = 0, LaunchPads = 0, Pickups = 0 }

    local function err(s, ...)
        table.insert(errors, select("#", ...) > 0 and s:format(...) or s)
    end
    local function warn(s, ...)
        table.insert(warnings, select("#", ...) > 0 and s:format(...) or s)
    end

    -- --- required shape. MapService iterates Center and Mirrored unguarded. ---
    for _, key in { "Name", "Size", "WallHeight", "Spawns", "Center", "Mirrored" } do
        if layout[key] == nil then
            err("missing required field %s", key)
        end
    end
    if #errors > 0 then
        return false, errors, warnings, info
    end

    local solids = Validate.solids(layout)
    info.Solids = #solids

    -- --- pieces: known kinds, well-formed, palette keys that exist ---
    local function checkPieces(list, label)
        for i, piece in list do
            local kind = piece.kind or "block"
            local where = ("%s[%d] %s"):format(label, i, piece.name or kind)
            if not Validate.KINDS[kind] then
                err("%s: unknown kind %q (placePiece would skip it silently)", where, kind)
            end
            if type(piece.pos) ~= "table" or #piece.pos ~= 3 then
                err("%s: pos must be {x, y, z}", where)
            end
            if Validate.KINDS[kind] and Validate.KINDS[kind].sized then
                if type(piece.size) ~= "table" or #piece.size ~= 3 then
                    err("%s: size must be {x, y, z}", where)
                end
            end
            if type(piece.color) == "string" and layout.Palette and layout.Palette[piece.color] == nil then
                err("%s: color %q is not a Palette key", where, piece.color)
            end
            if Validate.KINDS[kind] and Validate.KINDS[kind].asset then
                if type(piece.assetId) ~= "number" or piece.assetId <= 0 then
                    err("%s: prop needs a numeric `assetId` from the Creator Store", where)
                end
                if piece.scale ~= nil and (type(piece.scale) ~= "number" or piece.scale <= 0) then
                    err("%s: prop `scale` must be a positive number", where)
                end
                -- `fit` names the studs the model should end up; `scale` multiplies a
                -- size nobody measured. Setting both hides which one is in charge.
                if piece.fit ~= nil and (type(piece.fit) ~= "number" or piece.fit <= 0) then
                    err("%s: prop `fit` must be a positive number of studs", where)
                end
                if piece.fit ~= nil and piece.scale ~= nil then
                    err("%s: prop sets both `fit` and `scale`; keep `fit` and drop `scale`", where)
                end
                if piece.sit ~= nil and type(piece.sit) ~= "boolean" then
                    err("%s: prop `sit` must be true or false", where)
                end
                if piece.collide ~= nil and type(piece.collide) ~= "boolean" then
                    err("%s: prop `collide` must be true or false", where)
                end
                -- No `fidelity` field: CollisionFidelity is plugin-security, so nothing
                -- at runtime can write it. A collidable prop keeps the fidelity it was
                -- imported with. Reject the key rather than accept one that does nothing.
                if piece.fidelity ~= nil then
                    err("%s: prop `fidelity` cannot be set at runtime; CollisionFidelity is plugin-only", where)
                end
            end
            -- ramps: a thin slab with roll. Too steep stalls characters.
            if piece.rot and piece.size and #piece.size == 3 and piece.size[2] <= 2 then
                local roll = math.abs(piece.rot[3] or 0)
                if roll > 0.01 then
                    if roll > R.RampAngleMax then
                        err("%s: ramp angle %.0f deg is over %d, characters stall", where, roll, R.RampAngleMax)
                    elseif roll < R.RampAngleMin then
                        warn("%s: ramp angle %.0f deg is shallow", where, roll)
                    end
                end
            end
        end
    end
    checkPieces(layout.Center, "Center")
    checkPieces(layout.Mirrored, "Mirrored")
    -- Decor gets the same field checks -- a malformed piece still breaks the builder --
    -- but none of the fairness rules. That is the point of the list: scenery is not
    -- required to mirror, and an ice spike on one side is not a balance problem.
    checkPieces(layout.Decor or {}, "Decor")

    -- --- spawns ---
    for _, team in { "Red", "Blue" } do
        if not layout.Spawns[team] then
            err("Spawns.%s is missing", team)
        end
    end
    for team, points in layout.Spawns do
        if team ~= "Red" and team ~= "Blue" then
            err("Spawns.%s is not a team: MapService would build a grey pad nobody spawns on", tostring(team))
        end
        if #points ~= R.SpawnsPerTeam then
            warn("Spawns.%s has %d points, design target is %d", tostring(team), #points, R.SpawnsPerTeam)
        end
        for i, p in points do
            if not inBounds(layout, p) then
                err("Spawns.%s[%d] at %s is outside Bounds", tostring(team), i, fmt(p))
            end
            for j, q in points do
                if j > i then
                    local d = math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
                    if d < R.SpawnSpacingMin then
                        err(
                            "Spawns.%s[%d] and [%d] are %.1f studs apart, minimum %d: MapService cannot tell the pads apart when choosing a free one",
                            tostring(team),
                            i,
                            j,
                            d,
                            R.SpawnSpacingMin
                        )
                    end
                end
            end
        end
    end
    -- Red and Blue spawns must be each other's mirror
    if layout.Spawns.Red and layout.Spawns.Blue then
        for i, p in layout.Spawns.Red do
            local want = mirrorPos(p)
            local found = false
            for _, q in layout.Spawns.Blue do
                if samePos(q, want, R.MirrorEpsilon) then
                    found = true
                    break
                end
            end
            if not found then
                err("Spawns.Red[%d] at %s has no Blue mirror at %s", i, fmt(p), fmt(want))
            end
        end
    end

    -- --- objectives: unique names, inside bounds, fair placement ---
    local seenObjective = {}
    for i, o in layout.Objectives or {} do
        if not o.Name then
            err("Objectives[%d] has no Name", i)
        elseif seenObjective[o.Name] then
            err("duplicate objective id %q", o.Name)
        else
            seenObjective[o.Name] = true
        end
        if not o.radius or o.radius <= 0 then
            err("Objectives[%d] needs a positive radius", i)
        end
        if not inBounds(layout, o.pos) then
            err("Objective %q at %s is outside Bounds", tostring(o.Name), fmt(o.pos))
        end
        if math.abs(o.pos[1]) > R.MirrorEpsilon then
            warn("Objective %q at %s is off the centre line and favours one team", tostring(o.Name), fmt(o.pos))
        end
    end

    -- --- gameplay lists that must pair on the x-mirror ---
    local function pos(e)
        return e.pos
    end
    checkMirrored(errors, "LaunchPads", layout.LaunchPads, pos)
    checkMirrored(
        errors,
        "SniperOutposts",
        layout.SniperOutposts,
        pos,
        layout.Symmetry and layout.Symmetry.SniperOutposts
    )
    checkMirrored(errors, "Pickups", layout.Pickups, pos)
    checkMirrored(errors, "Barrier", layout.Barrier, pos)
    checkMirrored(errors, "SafeRegions", layout.SafeRegions, pos)
    checkMirrored(errors, "InvalidRegions", layout.InvalidRegions, pos)

    local seenOutpost = {}
    for i, o in layout.SniperOutposts or {} do
        if not o.Name then
            err("SniperOutposts[%d] has no Name", i)
        elseif seenOutpost[o.Name] then
            err("duplicate sniper outpost id %q", o.Name)
        else
            seenOutpost[o.Name] = true
        end
    end

    -- --- collidable props: real geometry no tracer can see ---
    -- A prop is somebody else's mesh, so the kind is `solid = false` and the arc tracer
    -- has no shape to sample. A piece that opts into `collide` is nonetheless in the way
    -- of bodies and bullets, which is the whole point of asking for it -- so it must stay
    -- off the routes that assume clear air. `fit` is the widest the model can end up, and
    -- half of that plus a margin is a deliberately generous radius: this cannot measure
    -- the mesh, so it errs toward complaining early.
    for _, piece in decorAndCentre(layout) do
        if piece.kind == "prop" and piece.collide == true and piece.pos then
            local radius = (piece.fit or 0) / 2 + 6
            local label = ("prop %s %s"):format(tostring(piece.name), fmt(piece.pos))
            for _, zip in layout.ZipLines or {} do
                local gap = pointToSegment(piece.pos, zip.From, zip.To)
                if gap < radius then
                    err(
                        "%s: collidable, and %.0f studs from zip line %s (needs %.0f)",
                        label,
                        gap,
                        tostring(zip.Id),
                        radius
                    )
                end
            end
            -- A launch arc bows upward, so the straight line from pad to target is the
            -- closest it ever comes to the ground: measuring against that flags early.
            for _, pad in layout.LaunchPads or {} do
                local gap = pointToSegment(piece.pos, pad.pos, pad.target)
                if gap < radius then
                    err(
                        "%s: collidable, and %.0f studs from launch pad %s (needs %.0f)",
                        label,
                        gap,
                        tostring(pad.Id),
                        radius
                    )
                end
            end
        end
    end

    -- --- launch pads: vy in range, arc clear, landing on floor and in bounds ---
    for i, pad in layout.LaunchPads or {} do
        info.LaunchPads += 1
        local label = ("LaunchPads[%d] %s"):format(i, fmt(pad.pos))
        if not pad.target then
            err("%s has no target", label)
        else
            local vy = pad.vy or 62
            if vy < R.LaunchVyMin or vy > R.LaunchVyMax then
                warn("%s: vy %g is outside %d-%d", label, vy, R.LaunchVyMin, R.LaunchVyMax)
            end
            local from = { pad.pos[1], pad.pos[2] + 2, pad.pos[3] }
            local gap, box, at, when = arcClearance(from, pad.target, vy, solids, 240)
            if gap < R.ArcClearError then
                err(
                    "%s: arc passes %.1f studs from %s at %s (%.2fs in) - the player clips it",
                    label,
                    gap,
                    box and box.name or "?",
                    at and fmt({ math.floor(at[1] + 0.5), math.floor(at[2] + 0.5), math.floor(at[3] + 0.5) }) or "?",
                    when
                )
            elseif gap < R.ArcClearWarn then
                warn("%s: arc clears %s by only %.1f studs", label, box and box.name or "?", gap)
            end
            if not inBounds(layout, pad.target) then
                err("%s: landing point %s is outside Bounds", label, fmt(pad.target))
            end
            local top = floorUnder(solids, pad.target)
            if top == nil then
                err("%s: nothing to land on under %s", label, fmt(pad.target))
            elseif pad.target[2] - top > R.LandingDrop then
                warn("%s: landing point is %.1f studs above the floor below it", label, pad.target[2] - top)
            end
            for _, bad in layout.InvalidRegions or {} do
                if inBox(pad.target, bad) then
                    err("%s: landing point is inside InvalidRegion %q", label, bad.name or "?")
                end
            end
            for _, event in layout.Events or {} do
                if event.Region and inBox(pad.target, event.Region) then
                    err("%s: landing point is inside the %q hazard region", label, event.Name or "?")
                end
            end
        end
    end

    -- --- pickups ---
    for i, p in layout.Pickups or {} do
        info.Pickups += 1
        if p.kind ~= "weapon" and p.kind ~= "speed" and p.kind ~= "jetpack" then
            err("Pickups[%d]: kind %q is not weapon/speed/jetpack", i, tostring(p.kind))
        end
        if p.kind == "weapon" then
            if not p.weapon then
                err("Pickups[%d]: weapon pickup with no weapon", i)
            elseif weapons and not weapons[p.weapon] then
                err("Pickups[%d]: unknown weapon %q", i, tostring(p.weapon))
            end
        end
        if not inBounds(layout, p.pos) then
            err("Pickups[%d] at %s is outside Bounds", i, fmt(p.pos))
        end
        -- PickupService floats the model ~2.5 studs up and collects by distance; buried in a
        -- prop it is unreachable, so check the pickup point itself is in open air
        for _, box in solids do
            if pointToBox(vec(p.pos), box) < 0.5 then
                err("Pickups[%d] at %s is inside %s", i, fmt(p.pos), box.name)
                break
            end
        end
    end

    -- --- safety data: required once players fight on floors far apart, or over water ---
    local lowest, highest = math.huge, -math.huge
    local function span(p)
        lowest, highest = math.min(lowest, p[2]), math.max(highest, p[2])
    end
    for _, points in layout.Spawns do
        for _, p in points do
            span(p)
        end
    end
    for _, list in { layout.Objectives, layout.Pickups, layout.LaunchPads, layout.SniperOutposts } do
        for _, e in list or {} do
            span(e.pos)
        end
    end
    -- Out-of-bounds is lethal in production, so the Bounds ceiling has to clear everything a
    -- player can legitimately reach. A jetpack burns its whole tank in one climb from the
    -- tallest thing they can stand on, and recharges on the ground, so they can do it again.
    local jet = weapons and weapons.Jetpack
    if jet and layout.Bounds then
        local burn = (jet.Burn and jet.Burn > 0) and (jet.Fuel / jet.Burn) or 0
        local hasJetpack = false
        for _, p in layout.Pickups or {} do
            if p.kind == "jetpack" then
                hasJetpack = true
                burn = math.max(burn, p.fuel or 3.5)
            end
        end
        if hasJetpack then
            local tallest = -math.huge
            for _, box in solids do
                tallest = math.max(tallest, box.aabb.max.y)
            end
            local ceiling = tallest + burn * (jet.Thrust or 0)
            if layout.Bounds.max[2] < ceiling then
                err(
                    "Bounds ceiling is %g but a jetpack reaches %.0f (%.0f stud climb from the tallest surface at %.0f): players would die for using one",
                    layout.Bounds.max[2],
                    ceiling,
                    burn * (jet.Thrust or 0),
                    tallest
                )
            end
        end
    end

    local drop = highest - lowest
    local overWater = layout.Terrain ~= nil and layout.Terrain.Sea == true
    if drop > R.DropHeight or overWater then
        local why = overWater and "it is built over water" or ("play spans %.0f studs of height"):format(drop)
        for _, key in { "RecoveryY", "Bounds", "SafePoints" } do
            if layout[key] == nil then
                err("%s is required: %s", key, why)
            end
        end
    end
    if layout.SafePoints and #layout.SafePoints < R.SafePointsMin then
        warn("SafePoints has %d entries, %d recommended", #layout.SafePoints, R.SafePointsMin)
    end
    for i, sp in layout.SafePoints or {} do
        if not inBounds(layout, sp.pos) then
            err("SafePoints[%d] %q is outside Bounds", i, sp.name or "?")
        end
        for _, bad in layout.InvalidRegions or {} do
            if inBox(sp.pos, bad) then
                local safe = false
                for _, ok in layout.SafeRegions or {} do
                    if inBox(sp.pos, ok) then
                        safe = true
                        break
                    end
                end
                if not safe then
                    err("SafePoints[%d] %q is inside InvalidRegion %q", i, sp.name or "?", bad.name or "?")
                end
            end
        end
    end
    -- a barrier segment should sit next to something; one in open air protects nothing
    for i, seg in layout.Barrier or {} do
        local near = false
        for _, box in solids do
            local a = box.aabb
            if
                seg.pos[1] > a.min.x - 6
                and seg.pos[1] < a.max.x + 6
                and seg.pos[3] > a.min.z - 6
                and seg.pos[3] < a.max.z + 6
                and seg.pos[2] > a.min.y - 14
                and seg.pos[2] < a.max.y + 14
            then
                near = true
                break
            end
        end
        if not near then
            err("Barrier[%d] at %s is not next to any geometry", i, fmt(seg.pos))
        end
    end

    return #errors == 0, errors, warnings, info
end

return Validate
