-- Reads an editable Convergence map (the template's markers) into layout data.
--
-- The ONE interpretation of the markers. Two callers, same code:
--   * MapService, in a Studio play session: the map model in Workspace is read live, so
--     pressing Play shows exactly what is in the viewport, with no file step at all.
--   * tools/mapauthor/convert.luau, under Lune: the saved source .rbxm becomes the
--     committed map module and bake.
-- It therefore requires nothing and uses only Instance APIs that both Roblox and Lune's
-- roblox library have. Callers pass in Validate and anything else it needs.
--
-- Positions are world coordinates. An earlier version measured from the model's pivot,
-- and Studio re-centres a pivot on Insert from File -- which sank a map 36.5 studs under
-- the terrain. World coordinates cannot drift like that.
local MapAuthoring = {}

MapAuthoring.FORMAT = 1
MapAuthoring.CONVERGENCE_OBJECTIVES = 3

-- Names the old GUIDE kit piece used. A map made from the template never has these
-- outside Authoring; one that does has a GUIDE dragged into it.
MapAuthoring.LEGACY_GUIDE = { "^GUIDE$", "^Bound_[XZ]", "^Objective_[ABC]", "^Centre$", "^Centre_Pole$", "^Spawn_[BR]" }

-- Sky, lighting and terrain for a map that has not set its own. Kept equal to the
-- commented default file the converter writes (check_map_authoring compares them).
function MapAuthoring.defaultPresentation()
    return {
        Terrain = {
            GroundMaterial = Enum.Material.Snow,
            GroundColor = Color3.fromRGB(226, 233, 240),
        },
        Palette = {
            Floor = Color3.fromRGB(180, 184, 190),
            Wall = Color3.fromRGB(102, 110, 122),
            Cover = Color3.fromRGB(122, 130, 140),
        },
        Environment = {
            Sky = {
                Ft = "rbxassetid://2029211409",
                Bk = "rbxassetid://2029210131",
                Lf = "rbxassetid://2029212393",
                Rt = "rbxassetid://2029212849",
                Up = "rbxassetid://2029213271",
                Dn = "rbxassetid://2029210773",
                CelestialBodiesShown = true,
            },
            ClockTime = 12,
            Brightness = 2,
            Ambient = Color3.fromRGB(160, 160, 160),
            OutdoorAmbient = Color3.fromRGB(170, 170, 170),
            FogStart = 900,
            FogEnd = 3000,
            FogColor = Color3.fromRGB(190, 195, 205),
            Atmosphere = { Density = 0, Haze = 0, Glare = 0, Color = Color3.fromRGB(255, 255, 255) },
            SunRays = 0,
            Bloom = 0,
            Saturation = 0,
            Contrast = 0,
            Tint = Color3.fromRGB(255, 255, 255),
        },
    }
end

-- Positions are kept to 3 decimals, so generated data is stable and diffable.
function MapAuthoring.num(n)
    assert(n == n and n ~= math.huge and n ~= -math.huge, "non-finite number in map data")
    local s = string.format("%.3f", n)
    s = (s:gsub("0+$", ""))
    s = (s:gsub("%.$", ""))
    if s == "-0" then
        s = "0"
    end
    return s
end
local num = MapAuthoring.num

local function r3(p)
    return { tonumber(num(p[1])), tonumber(num(p[2])), tonumber(num(p[3])) }
end

local function pathOf(inst, root)
    local parts = {}
    local i = inst
    while i and i ~= root do
        table.insert(parts, 1, i.Name)
        i = i.Parent
    end
    return table.concat(parts, " > ")
end

local function within(inst, ancestor)
    local i = inst.Parent
    while i do
        if i == ancestor then
            return true
        end
        i = i.Parent
    end
    return false
end

local function naturalLess(a, b)
    local function pad(s)
        return (s:lower():gsub("%d+", function(d)
            return string.rep("0", 8 - #d) .. d
        end))
    end
    return pad(a) < pad(b)
end

-- ===== markers =====

-- Read the markers under `root`. Returns `authored` (plain numbers) or nil, plus errors
-- and warnings, each naming the object and the fix.
function MapAuthoring.readMarkers(root, name)
    local errors, warnings = {}, {}
    local function err(s)
        table.insert(errors, name .. ": " .. s)
    end
    local function warn(s)
        table.insert(warnings, name .. ": " .. s)
    end

    local authoring = root:FindFirstChild("Authoring")
    if not authoring then
        err("the Authoring folder is missing, so there are no objectives or spawns. Restore the previous version.")
        return nil, errors, warnings
    end

    local objectives, spawns, bounds = {}, { Blue = {}, Red = {} }, {}
    for _, inst in root:GetDescendants() do
        local role = inst:GetAttribute("Role")
        if role ~= nil then
            local at = pathOf(inst, root)
            if not within(inst, authoring) then
                err(
                    ("%s is a %s marker outside the Authoring folder, where it would be ignored. "):format(
                        at,
                        tostring(role)
                    ) .. "Drag it back into Authoring in the Explorer."
                )
            elseif role == "Objective" then
                table.insert(objectives, inst)
            elseif role == "Spawn" then
                local team = inst:GetAttribute("Team")
                if team ~= "Blue" and team ~= "Red" then
                    err(("%s has Team = %q; it must be Blue or Red."):format(at, tostring(team)))
                else
                    local folderTeam = inst.Parent and inst.Parent.Name
                    if (folderTeam == "Blue" or folderTeam == "Red") and folderTeam ~= team then
                        err(
                            ("%s sits in the %s folder but its Team attribute says %s. Set Team to %s, or move it back."):format(
                                at,
                                folderTeam,
                                team,
                                folderTeam
                            )
                        )
                    else
                        table.insert(spawns[team], inst)
                    end
                end
            elseif role == "Bounds" then
                table.insert(bounds, inst)
            else
                err(("%s has an unknown Role %q (expected Objective, Spawn or Bounds)."):format(at, tostring(role)))
            end
        end
    end

    local authored = { Objectives = {}, Spawns = { Blue = {}, Red = {} } }

    -- objectives
    local seenId, seenLabel = {}, {}
    table.sort(objectives, function(a, b)
        return tostring(a:GetAttribute("ObjectiveId")) < tostring(b:GetAttribute("ObjectiveId"))
    end)
    for _, inst in objectives do
        local at = pathOf(inst, root)
        local id = inst:GetAttribute("ObjectiveId")
        local what = ("Objective %s (%s)"):format(tostring(id), at)
        if type(id) ~= "string" or not id:match("^[%w_%-]+$") or #id > 24 then
            err(
                ("%s has ObjectiveId %q. It needs a short ID of letters, digits, - or _ (e.g. A). "):format(
                    at,
                    tostring(id)
                ) .. "Set it in the Properties panel under Attributes."
            )
            continue
        end
        if seenId[id] then
            err(
                ("two objectives share ObjectiveId %q (%s and %s). Give the copy a new ID in Properties > Attributes."):format(
                    id,
                    seenId[id],
                    at
                )
            )
            continue
        end
        seenId[id] = at
        local capture = inst:IsA("BasePart") and inst or inst:FindFirstChild("Capture")
        if not capture or not capture:IsA("BasePart") then
            err(what .. " has lost its Capture cylinder. Undo, or restore the previous version.")
            continue
        end
        if capture.Shape ~= Enum.PartType.Cylinder then
            err(what .. ": its Capture part is not a cylinder any more. Set Shape back to Cylinder.")
            continue
        end
        local cf = capture.CFrame
        if math.abs(cf.RightVector.Y) < 0.999 then
            err(
                what
                    .. " is tilted. Capture areas stand upright: set the Capture part's Orientation to 0, 0, 90 "
                    .. "(or 0, <any>, 90 to spin it)."
            )
            continue
        end
        local size = capture.Size
        local radius = math.min(size.Y, size.Z) / 2
        if math.abs(size.Y - size.Z) > 0.05 then
            warn(
                ("%s is stretched into an oval (%.1f x %.1f). Capture areas are circles; radius %.1f is used."):format(
                    what,
                    size.Y,
                    size.Z,
                    radius
                )
            )
        end
        local halfHeight = size.X
        local label = inst:GetAttribute("Label")
        if type(label) ~= "string" or label == "" then
            warn(what .. " has no Label attribute; showing its ID in game.")
            label = id
        end
        if seenLabel[label] then
            err(
                ("objectives %s and %s both have Label %q. Players could not tell them apart; change one Label."):format(
                    seenLabel[label],
                    id,
                    label
                )
            )
        end
        seenLabel[label] = id
        local eligible = inst:GetAttribute("FinaleEligible")
        if type(eligible) ~= "boolean" then
            err(
                what
                    .. " has no FinaleEligible setting. Add a boolean attribute FinaleEligible (true lets the "
                    .. "match end there)."
            )
            continue
        end
        -- the point is the bottom centre of the cylinder: where it touches the floor
        local centre = cf.Position
        table.insert(authored.Objectives, {
            Id = id,
            Label = label,
            Where = what,
            pos = { centre.X, centre.Y - halfHeight / 2, centre.Z },
            radius = radius,
            halfHeight = halfHeight,
            finale = eligible,
        })
        local text = inst:FindFirstChild("Label", true)
        text = text and text:FindFirstChildWhichIsA("TextLabel")
        if text and text.Text ~= "OBJECTIVE " .. id then
            warn(
                ("%s: the viewport label reads %q but the ID is %s. Edit Pole > Label > Text so it matches."):format(
                    what,
                    text.Text,
                    id
                )
            )
        end
    end
    local ids = {}
    for _, o in authored.Objectives do
        table.insert(ids, o.Id)
    end
    local want = MapAuthoring.CONVERGENCE_OBJECTIVES
    if #objectives ~= want then
        err(
            ("Convergence needs exactly %d objectives; the map has %d%s. "):format(
                want,
                #objectives,
                #ids > 0 and (" (" .. table.concat(ids, ", ") .. ")") or ""
            )
                .. (
                    #objectives < want
                        and "Duplicate one (Ctrl+D) in Authoring > Objectives and give it a new ObjectiveId."
                    or "Delete the extra one from Authoring > Objectives."
                )
        )
    end

    -- spawns
    for _, team in { "Blue", "Red" } do
        local list = spawns[team]
        table.sort(list, function(a, b)
            if a.Name ~= b.Name then
                return naturalLess(a.Name, b.Name)
            end
            local pa, pb = a.CFrame.Position, b.CFrame.Position
            return pa.X < pb.X or (pa.X == pb.X and pa.Z < pb.Z)
        end)
        local seenName = {}
        for _, inst in list do
            local what = ("%s spawn %q (%s)"):format(team, inst.Name, pathOf(inst, root))
            if not inst:IsA("BasePart") then
                err(what .. " is not a part. Spawn markers are the flat pads from the template.")
                continue
            end
            if seenName[inst.Name] then
                warn(
                    ("two %s spawns are named %q; rename the copy so messages can tell them apart."):format(
                        team,
                        inst.Name
                    )
                )
            end
            seenName[inst.Name] = true
            local cf = inst.CFrame
            if math.abs(cf.UpVector.Y) < 0.999 then
                err(what .. " is tilted. Spawn pads lie flat: set Orientation to 0, <any>, 0.")
                continue
            end
            local c = cf.Position
            table.insert(authored.Spawns[team], {
                Name = inst.Name,
                Where = what,
                pos = { c.X, c.Y - inst.Size.Y / 2, c.Z },
            })
        end
        if #list == 0 then
            err(
                ("the %s team has no spawn markers. Copy a pad from Authoring > Spawns > %s, or undo the delete."):format(
                    team,
                    team
                )
            )
        end
    end

    -- bounds
    if #bounds ~= 1 then
        err(
            ("the map needs exactly one Map Boundary (Authoring > Bounds); found %d. "):format(#bounds)
                .. "Delete extras, or restore the previous version if it was deleted."
        )
    else
        local box = bounds[1]
        local cf = box.CFrame
        local up, right = cf.UpVector, cf.RightVector
        if math.abs(up.Y) < 0.999 or (math.abs(right.X) < 0.999 and math.abs(right.Z) < 0.999) then
            err(
                "the Map Boundary is rotated. It must line up with the world axes: set its Orientation to "
                    .. "0, 0, 0. If you turned the whole map model, turn it back (Ctrl+Z)."
            )
        else
            local sx, sz = box.Size.X, box.Size.Z
            if math.abs(right.Z) > 0.999 then
                sx, sz = sz, sx
            end
            local c = cf.Position
            local minV = { c.X - sx / 2, c.Y - box.Size.Y / 2, c.Z - sz / 2 }
            local maxV = { c.X + sx / 2, c.Y + box.Size.Y / 2, c.Z + sz / 2 }
            if sx < 40 or sz < 40 or box.Size.Y < 20 then
                err(
                    ("the Map Boundary is only %.0f x %.0f x %.0f studs. Scale it up to enclose the playable space."):format(
                        sx,
                        box.Size.Y,
                        sz
                    )
                )
            end
            local teleport = box:GetAttribute("TeleportOnExit")
            if type(teleport) ~= "boolean" then
                warn("the Map Boundary has no TeleportOnExit attribute; players leaving it are teleported back.")
                teleport = true
            end
            authored.Bounds = { min = minV, max = maxV, teleport = teleport }
        end
    end

    if #errors > 0 then
        return nil, errors, warnings
    end
    return authored, errors, warnings
end

-- ===== geometry =====

-- Copy everything outside Authoring into a new Folder named `name` (`Instance` is the
-- caller's: Roblox's global, or Lune's roblox.Instance). The source is not touched.
function MapAuthoring.bake(root, name, Instance)
    local errors, warnings = {}, {}
    local function err(s)
        table.insert(errors, name .. ": " .. s)
    end
    local authoring = root:FindFirstChild("Authoring")
    local bake = Instance.new("Folder")
    bake.Name = name
    for _, child in root:GetChildren() do
        if child ~= authoring then
            child:Clone().Parent = bake
        end
    end
    local parts = 0
    for _, inst in bake:GetDescendants() do
        if inst:IsA("BasePart") then
            parts += 1
        end
        -- Creator Store models often carry scripts, and a script in the map would run on
        -- the live server. Props never need one.
        if inst:IsA("LuaSourceContainer") then
            err(
                ("%s is a script inside a map piece. Scripts in map geometry would run in the game; "):format(
                    pathOf(inst, bake)
                ) .. "delete it (free models often bring them along)."
            )
        end
        for _, pattern in MapAuthoring.LEGACY_GUIDE do
            if inst.Name:match(pattern) then
                err(
                    ("%s looks like part of the old GUIDE kit piece. Delete it; the template's own markers "):format(
                        pathOf(inst, bake)
                    ) .. "are in Authoring."
                )
                break
            end
        end
        if inst:GetAttribute("AuthoringHelper") ~= nil then
            err(
                ("%s is an authoring helper outside the Authoring folder. Drag it back into Authoring, or delete it."):format(
                    pathOf(inst, bake)
                )
            )
        end
    end
    local geometry = root:FindFirstChild("Geometry")
    if not geometry then
        table.insert(
            warnings,
            name
                .. ": there is no Geometry folder. Anything outside Authoring still counts, but keep pieces in Geometry."
        )
    elseif #geometry:GetChildren() == 0 then
        table.insert(
            warnings,
            name
                .. ": Geometry is empty. Pieces placed loose in Workspace are not part of the map -- drag them onto "
                .. "Geometry in the Explorer."
        )
    end
    return bake, parts, errors, warnings
end

-- Collidable box list (Validate's shape) plus a flat part list, from instances.
-- Property reads are guarded because Lune leaves some unset properties unreadable.
function MapAuthoring.solids(roots, Validate)
    local solids, parts = {}, {}
    local function walk(inst)
        if inst:IsA("BasePart") then
            local okCf, cf = pcall(function()
                return inst.CFrame
            end)
            local okSize, size = pcall(function()
                return inst.Size
            end)
            local okCollide, collide = pcall(function()
                return inst.CanCollide
            end)
            if okCf and okSize then
                local x, y, z, a, b, c, d, e, f, g, h, k = cf:GetComponents()
                local pos = { x, y, z }
                local dim = { size.X, size.Y, size.Z }
                -- Axis-aligned within a hair. Gates that test a point against a box with an
                -- abs() per axis are only correct for unrotated parts.
                local square = math.abs(math.abs(a) - 1) < 1e-4
                    and math.abs(math.abs(e) - 1) < 1e-4
                    and math.abs(math.abs(k) - 1) < 1e-4
                table.insert(parts, {
                    name = inst.Name,
                    pos = pos,
                    size = dim,
                    collide = okCollide and collide or false,
                    axisAligned = square,
                })
                if okCollide and collide then
                    table.insert(
                        solids,
                        Validate.boxFrom(inst.Name, pos, dim, { { a, b, c }, { d, e, f }, { g, h, k } })
                    )
                end
            end
        end
        for _, child in inst:GetChildren() do
            walk(child)
        end
    end
    for _, root in roots do
        walk(root)
    end
    return solids, parts
end

-- ===== layout =====

-- Which sides of the boundary have ground near them. A barrier segment in open air
-- protects nothing, and Validate rejects one; where the ground stops short, players are
-- recovered by the boundary itself instead.
local function nearGeometry(solids, pos)
    for _, box in solids do
        local a = box.aabb
        if
            pos[1] > a.min.x - 6
            and pos[1] < a.max.x + 6
            and pos[3] > a.min.z - 6
            and pos[3] < a.max.z + 6
            and pos[2] > a.min.y - 14
            and pos[2] < a.max.y + 14
        then
            return true
        end
    end
    return false
end

-- The layout table MapService builds from: every spatial value derived from markers,
-- presentation merged in. `solids` is the map's own geometry.
function MapAuthoring.generate(name, authored, presentation, revision, solids)
    local warnings = {}
    local b = authored.Bounds
    local floorY = math.huge
    for _, team in { "Blue", "Red" } do
        for _, s in authored.Spawns[team] do
            floorY = math.min(floorY, s.pos[2])
        end
    end
    if floorY == math.huge then
        floorY = 0
    end
    local reach = 0
    for _, v in { b.min[1], b.max[1], b.min[3], b.max[3] } do
        reach = math.max(reach, math.abs(v))
    end

    local objectives, eligible = {}, {}
    for _, o in authored.Objectives do
        table.insert(objectives, {
            Id = o.Id,
            Name = o.Label,
            pos = r3(o.pos),
            radius = tonumber(num(o.radius)),
            halfHeight = tonumber(num(o.halfHeight)),
            Phases = { 1, 2, 3 },
        })
        if o.finale then
            table.insert(eligible, o.Id)
        end
    end

    local spawns = { Blue = {}, Red = {} }
    local safe = {}
    for _, team in { "Blue", "Red" } do
        local list = authored.Spawns[team]
        local cx, cz = 0, 0
        for _, s in list do
            table.insert(spawns[team], r3(s.pos))
            cx += s.pos[1] / #list
            cz += s.pos[3] / #list
        end
        -- the pad nearest the group's middle: a centroid can land inside a wall
        local best, bestD = nil, math.huge
        for _, s in list do
            local d = (s.pos[1] - cx) ^ 2 + (s.pos[3] - cz) ^ 2
            if d < bestD then
                best, bestD = s, d
            end
        end
        if best then
            table.insert(safe, { name = team .. " spawn", pos = r3({ best.pos[1], best.pos[2] + 1, best.pos[3] }) })
        end
    end
    for _, o in authored.Objectives do
        table.insert(safe, { name = "Objective " .. o.Id, pos = r3({ o.pos[1], o.pos[2] + 1, o.pos[3] }) })
    end

    local barrier = {}
    local lx, lz = b.max[1] - b.min[1], b.max[3] - b.min[3]
    local cx, cz = (b.max[1] + b.min[1]) / 2, (b.max[3] + b.min[3]) / 2
    local y = floorY + 6
    for _, side in
        {
            { "north", { cx, y, b.min[3] - 1.5 }, { lx, 12, 1.5 } },
            { "south", { cx, y, b.max[3] + 1.5 }, { lx, 12, 1.5 } },
            { "west", { b.min[1] - 1.5, y, cz }, { 1.5, 12, lz } },
            { "east", { b.max[1] + 1.5, y, cz }, { 1.5, 12, lz } },
        }
    do
        if nearGeometry(solids, side[2]) then
            table.insert(barrier, { pos = r3(side[2]), size = r3(side[3]) })
        else
            table.insert(
                warnings,
                ("%s: the ground stops more than 6 studs short of the boundary's %s edge, so there is no "):format(
                    name,
                    side[1]
                )
                    .. "invisible wall there. Players who walk off are recovered by the boundary. Extend Ground "
                    .. "to it if you want a wall."
            )
        end
    end

    local vista = presentation.Vista
        or {
            pos = r3({ b.min[1] + 20, floorY + 80, b.min[3] - 5 }),
            look = r3({ cx, floorY + 8, cz }),
            seconds = 3,
        }

    return {
        Name = name,
        Revision = revision,
        Draft = true,
        RequiresBake = true,
        Authored = {
            Source = "assets/environment/source/" .. name .. ".rbxm",
            Presentation = "assets/environment/source/" .. name .. ".presentation.lua",
            Format = MapAuthoring.FORMAT,
        },
        Size = math.ceil(reach * 2 / 10) * 10,
        WallHeight = 12,
        Seed = presentation.Seed or 0,
        Finale = { EligibleIds = eligible },
        Objectives = objectives,
        Spawns = spawns,
        Bounds = { min = r3(b.min), max = r3(b.max) },
        RecoveryY = tonumber(num(b.min[2])),
        SafetyAlwaysOn = b.teleport,
        SafePoints = safe,
        Barrier = barrier,
        InvalidRegions = {},
        SafeRegions = {},
        Vista = vista,
        Terrain = presentation.Terrain,
        Palette = presentation.Palette or {},
        Environment = presentation.Environment,
        Center = {},
        Mirrored = {},
        Decor = {},
    },
        warnings
end

-- ===== placement checks =====

local function pointToBox(p, box)
    local dx, dy, dz = p[1] - box.c.x, p[2] - box.c.y, p[3] - box.c.z
    local m = box.m
    local lx = m[1][1] * dx + m[2][1] * dy + m[3][1] * dz
    local ly = m[1][2] * dx + m[2][2] * dy + m[3][2] * dz
    local lz = m[1][3] * dx + m[2][3] * dy + m[3][3] * dz
    local ox = math.max(0, math.abs(lx) - box.h.x)
    local oy = math.max(0, math.abs(ly) - box.h.y)
    local oz = math.max(0, math.abs(lz) - box.h.z)
    return math.sqrt(ox * ox + oy * oy + oz * oz)
end

local function onTerrain(layout, p, tolBelow, tolAbove)
    local t = layout.Terrain
    if not t or t.Sea then
        return false
    end
    local half = layout.Size * 2
    return math.abs(p[1]) <= half and math.abs(p[3]) <= half and p[2] >= -tolAbove and p[2] <= tolBelow
end

-- The terrain field fills everything below y = 0 across the map, so a point below it
-- is inside solid ground.
local function underTerrain(layout, p)
    local t = layout.Terrain
    if not t or t.Sea then
        return false
    end
    local half = layout.Size * 2
    return math.abs(p[1]) <= half and math.abs(p[3]) <= half and p[2] < -1
end

-- true, or false and a phrase about why not
local function support(layout, solids, p)
    for _, box in solids do
        if pointToBox({ p[1], p[2] - 0.5, p[3] }, box) <= 0.6 then
            return true
        end
    end
    if onTerrain(layout, p, 1.1, 0.5) then
        return true
    end
    local below, belowName = -math.huge, nil
    for _, box in solids do
        local a = box.aabb
        if p[1] >= a.min.x and p[1] <= a.max.x and p[3] >= a.min.z and p[3] <= a.max.z and a.max.y <= p[2] then
            if a.max.y > below then
                below, belowName = a.max.y, box.name
            end
        end
    end
    if onTerrain(layout, { p[1], 0, p[3] }, 1, 1) and p[2] > 0 and 0 > below then
        below, belowName = 0, "the terrain"
    end
    if belowName then
        return false, ("floats %.1f studs above %s"):format(p[2] - below, belowName), below
    end
    return false, "has nothing under it"
end

-- The solid containing a point, and how high its top is right there.
local function insideSolid(solids, p)
    for _, box in solids do
        if pointToBox(p, box) == 0 then
            -- walk up until out of the box: its surface at this spot, to a tenth of a stud
            local y = p[2]
            while pointToBox({ p[1], y, p[3] }, box) == 0 and y < p[2] + 500 do
                y += 0.1
            end
            return box.name, y
        end
    end
    return nil
end

-- A floor players can actually stand on: nothing solid in the space just above it.
local function standable(solids, p, top)
    return insideSolid(solids, { p[1], top + 2.5, p[3] }) == nil
end

-- Pivot Y for an objective whose floor point should be at `floorY`. The objective's
-- pivot is its Capture cylinder's centre, half its height above the floor point.
local function objectivePivotY(o, floorY)
    return floorY + o.halfHeight / 2
end

local function inBounds(b, p)
    for i = 1, 3 do
        if p[i] < b.min[i] - 1e-6 or p[i] > b.max[i] + 1e-6 then
            return false
        end
    end
    return true
end

-- Is this map playable as authored? Plain-language errors (blocking) and warnings.
function MapAuthoring.check(name, layout, solids, authored, Validate, weapons)
    local errors, warnings = {}, {}
    local function err(s)
        table.insert(errors, name .. ": " .. s)
    end
    local function warn(s)
        table.insert(warnings, name .. ": " .. s)
    end

    local b = layout.Bounds
    local cx, cz = (b.min[1] + b.max[1]) / 2, (b.min[3] + b.max[3]) / 2
    if math.sqrt(cx * cx + cz * cz) > 50 then
        warn(
            ("the map's centre is at (%.0f, %.0f), %.0f studs from the world origin. Players spawn facing the origin "):format(
                cx,
                cz,
                math.sqrt(cx * cx + cz * cz)
            )
                .. "and the terrain is centred on it. If you moved the whole map by accident, move it back."
        )
    end
    for _, o in authored.Objectives do
        if not inBounds(b, o.pos) then
            err(("%s is outside the Map Boundary. Move it inside, or enlarge the boundary."):format(o.Where))
        end
        if o.radius < 4 then
            err(
                ("%s has a capture radius of %.1f studs; players could barely stand in it. "):format(o.Where, o.radius)
                    .. "Scale the Capture cylinder up."
            )
        end
        if o.halfHeight < 4 then
            err(
                ("%s's capture cylinder is %.1f studs tall; a standing player needs at least 4 to count. "):format(
                    o.Where,
                    o.halfHeight
                ) .. "Scale its height up."
            )
        end
        if underTerrain(layout, o.pos) then
            err(
                ("%s is %.1f studs under the terrain surface (y = 0), where nobody can reach it. "):format(
                    o.Where,
                    -o.pos[2]
                ) .. "If the whole map was moved down, move it back up."
            )
        end
        local ok, why, below = support(layout, solids, o.pos)
        if not ok then
            err(
                ("%s %s. Drag it down onto a floor (the bottom of the cylinder is the floor point)"):format(
                    o.Where,
                    why
                )
                    .. (
                        below
                            and ("; or set its Pivot > Origin > Position Y to %.1f."):format(objectivePivotY(o, below))
                        or "."
                    )
            )
        end
        local buried, buriedTop = insideSolid(solids, { o.pos[1], o.pos[2] + 1, o.pos[3] })
        if buried then
            err(
                ("%s is sunk %.1f studs into %s. Raise it %.1f studs: select it and set Pivot > Origin > Position Y to %.1f."):format(
                    o.Where,
                    buriedTop - o.pos[2],
                    buried,
                    buriedTop - o.pos[2],
                    objectivePivotY(o, buriedTop)
                )
            )
        end
        -- other floors inside the capture height (it extends as far below as above)
        for _, box in solids do
            local a = box.aabb
            if o.pos[1] >= a.min.x and o.pos[1] <= a.max.x and o.pos[3] >= a.min.z and o.pos[3] <= a.max.z then
                local top = a.max.y
                if not standable(solids, o.pos, top) then
                    continue
                end
                if top > o.pos[2] + 1.5 and top <= o.pos[2] + o.halfHeight - 3 then
                    warn(
                        ("%s: players standing on %s (top at y %.1f) are inside its capture height."):format(
                            o.Where,
                            box.name,
                            top
                        )
                    )
                elseif top < o.pos[2] - 2 and top >= o.pos[2] - o.halfHeight - 3 then
                    warn(
                        ("%s: players on %s, %.1f studs below, still count -- the capture area reaches %.1f studs down. "):format(
                            o.Where,
                            box.name,
                            o.pos[2] - top,
                            o.halfHeight
                        )
                            .. "Shorten the cylinder or raise the objective if that floor is a different level."
                    )
                end
            end
        end
    end
    for _, team in { "Blue", "Red" } do
        local list = authored.Spawns[team]
        for i, s in list do
            if not inBounds(b, s.pos) then
                err(("%s is outside the Map Boundary. Move the spawn inside, or enlarge the boundary."):format(s.Where))
            end
            if underTerrain(layout, s.pos) then
                err(
                    ("%s is %.1f studs under the terrain surface (y = 0); players would spawn inside it. "):format(
                        s.Where,
                        -s.pos[2]
                    ) .. "If the whole map was moved down, move it back up."
                )
            end
            local ok, why, below = support(layout, solids, s.pos)
            if not ok then
                err(
                    ("%s %s. Drag it onto a floor"):format(s.Where, why)
                        .. (below and ("; or set its Position Y to %.2f."):format(below + 0.25) or ".")
                )
            end
            local blocked = insideSolid(solids, { s.pos[1], s.pos[2] + 2.5, s.pos[3] })
            if blocked then
                err(
                    ("%s is inside %s; a player would spawn in it. Move the pad into open space."):format(
                        s.Where,
                        blocked
                    )
                )
            end
            for j = i + 1, #list do
                local q = list[j]
                local d = math.sqrt((s.pos[1] - q.pos[1]) ^ 2 + (s.pos[2] - q.pos[2]) ^ 2 + (s.pos[3] - q.pos[3]) ^ 2)
                if d < Validate.RULES.SpawnSpacingMin then
                    err(
                        ("%s and %s are %.1f studs apart; keep pads at least %d apart so two players are not placed on the same one."):format(
                            s.Where,
                            q.Name,
                            d,
                            Validate.RULES.SpawnSpacingMin
                        )
                    )
                end
            end
        end
    end
    if #solids == 0 and not (layout.Terrain and not layout.Terrain.Sea) then
        err("there is nothing to stand on: no collidable parts and no terrain.")
    end

    local eligible = layout.Finale and layout.Finale.EligibleIds or {}
    if #layout.Objectives == MapAuthoring.CONVERGENCE_OBJECTIVES and #eligible < 2 then
        err(
            ("only %d objective(s) have FinaleEligible = true; the finale needs at least 2 (the template makes all 3 eligible)."):format(
                #eligible
            )
        )
    end

    -- the shared map rules, the same check check_maps runs
    if #errors == 0 then
        local ok, vErrors, vWarnings = Validate.check(layout, weapons, solids)
        if not ok then
            for _, e in vErrors do
                err("map rule: " .. e)
            end
        end
        -- One sentence about spawn fairness, not one line per pad: the rule assumes
        -- teams mirrored across x = 0, and a draft may be trying something else.
        local unmirrored = 0
        for _, w in vWarnings do
            if w:find("has no Blue mirror", 1, true) then
                unmirrored += 1
            else
                warn(w)
            end
        end
        if unmirrored > 0 then
            warn(
                ("%d Red spawn(s) are not mirror images of a Blue spawn across the centre line (x = 0). "):format(
                    unmirrored
                )
                    .. "Fine while designing; before the map goes public, check both teams' travel times in a playtest."
            )
        end
    end
    return errors, warnings
end

-- Everything above in one call, for a map model in hand. Returns layout, bake folder,
-- errors, warnings. `presentation` defaults to defaultPresentation().
function MapAuthoring.read(root, name, opts)
    local errors, warnings = {}, {}
    local function add(list, more)
        for _, v in more do
            table.insert(list, v)
        end
    end
    local authored, e1, w1 = MapAuthoring.readMarkers(root, name)
    add(errors, e1)
    add(warnings, w1)
    local bake, parts, e2, w2 = MapAuthoring.bake(root, name, opts.Instance)
    add(errors, e2)
    add(warnings, w2)
    if not authored or #errors > 0 then
        return nil, bake, errors, warnings, authored, parts
    end
    local solids = MapAuthoring.solids({ bake }, opts.Validate)
    local layout, w3 = MapAuthoring.generate(
        name,
        authored,
        opts.presentation or MapAuthoring.defaultPresentation(),
        opts.revision or "live",
        solids
    )
    add(warnings, w3)
    local e4, w4 = MapAuthoring.check(name, layout, solids, authored, opts.Validate, opts.weapons)
    add(errors, e4)
    add(warnings, w4)
    return layout, bake, errors, warnings, authored, parts
end

return MapAuthoring
