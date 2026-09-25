-- Editable map source -> playable bake + map data, and the checks that go with it.
--
-- One authored file, two generated ones:
--
--     assets/environment/source/<Name>.rbxm               the editable map, markers and all
--     assets/environment/source/<Name>.presentation.lua   sky, palette, terrain (optional edits)
--  -> assets/environment/baked/<Name>.rbxm                playable geometry, no markers
--  -> src/shared/Maps/<Name>.lua                          every spatial number, generated
--
-- Spatial values have exactly one home: the markers in the source. The map module is
-- regenerated from them on every conversion and never edited by hand, and the runtime
-- and every gate read that module. There is no second marker reader anywhere.
--
-- Positions are plain world coordinates. An earlier version measured everything from
-- the model's pivot so that moving the whole map would change nothing, but Studio resets
-- a model's pivot to its bounding-box centre on Insert from File -- which silently sank
-- a map 36.5 studs under the terrain. World coordinates cannot drift like that. Moving
-- the whole map moves every marker with it, so the result stays consistent, and a map
-- dragged away from the origin or under the terrain is reported. Only a marker transform
-- that cannot be turned into data -- a tilted capture area, a rotated boundary -- is refused.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

local Validate = require("../../src/shared/Maps/Validate")
local FinalePlan = require("../../src/server/FinalePlan")
local Baked = require("../bakedsolids")
local Template = require("./template")

local C = {}

C.FORMAT = 1
-- Positions are written to 3 decimals. Authored and generated values must agree to
-- this, which is looser than the rounding and far tighter than anything a player sees.
C.TOLERANCE = 0.01
C.CONVERGENCE_OBJECTIVES = 3

-- Names the old GUIDE kit piece used. A map made from the template never has these
-- outside Authoring; one that does has a GUIDE dragged into it.
local LEGACY_GUIDE = { "^GUIDE$", "^Bound_[XZ]", "^Objective_[ABC]", "^Centre$", "^Centre_Pole$", "^Spawn_[BR]" }

function C.paths(root, name)
    return {
        source = root .. "/assets/environment/source/" .. name .. ".rbxm",
        presentation = root .. "/assets/environment/source/" .. name .. ".presentation.lua",
        bake = root .. "/assets/environment/baked/" .. name .. ".rbxm",
        map = root .. "/src/shared/Maps/" .. name .. ".lua",
        -- repo-relative, for messages and the Authored block
        relSource = "assets/environment/source/" .. name .. ".rbxm",
        relPresentation = "assets/environment/source/" .. name .. ".presentation.lua",
        relBake = "assets/environment/baked/" .. name .. ".rbxm",
        relMap = "src/shared/Maps/" .. name .. ".lua",
    }
end

-- ===== Lua writer =====
-- Deterministic: sorted keys, fixed decimals, no timestamps. Unchanged source must
-- produce byte-identical output, or the freshness gate cries wolf.

local function num(n)
    assert(n == n and n ~= math.huge and n ~= -math.huge, "non-finite number in map data")
    local s = string.format("%.3f", n)
    s = (s:gsub("0+$", ""))
    s = (s:gsub("%.$", ""))
    if s == "-0" then
        s = "0"
    end
    return s
end
C.num = num

local function isArray(t)
    local n = 0
    for _ in t do
        n += 1
    end
    return n == #t
end

local function key(k)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
        return k
    end
    return "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]"
end

local function emit(v, indent, order)
    local t = typeof(v)
    if t == "number" then
        return num(v)
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "boolean" then
        return tostring(v)
    elseif t == "Color3" then
        return ("Color3.fromRGB(%d, %d, %d)"):format(
            math.round(v.R * 255),
            math.round(v.G * 255),
            math.round(v.B * 255)
        )
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t ~= "table" then
        error("cannot write a " .. t .. " into map data")
    end
    local pad = string.rep("    ", indent + 1)
    local items = {}
    if isArray(v) then
        for _, x in v do
            table.insert(items, emit(x, indent + 1))
        end
    else
        local keys = {}
        for k in v do
            table.insert(keys, k)
        end
        local rank = {}
        for i, k in order or {} do
            rank[k] = i
        end
        table.sort(keys, function(a, b)
            local ra, rb = rank[a] or math.huge, rank[b] or math.huge
            if ra ~= rb then
                return ra < rb
            end
            return tostring(a) < tostring(b)
        end)
        for _, k in keys do
            table.insert(items, key(k) .. " = " .. emit(v[k], indent + 1))
        end
    end
    if #items == 0 then
        return "{}"
    end
    local inline = "{ " .. table.concat(items, ", ") .. " }"
    if #inline + #pad <= 110 and not inline:find("\n") then
        return inline
    end
    return "{\n" .. pad .. table.concat(items, ",\n" .. pad) .. ",\n" .. string.rep("    ", indent) .. "}"
end

-- ===== presentation =====

C.PRESENTATION_DEFAULT = [[
-- Presentation for this map: sky, lighting, terrain and palette. Optional to edit.
--
-- This file is yours. The converter created it once with defaults and never
-- overwrites it; your edits are merged into the generated map every conversion.
-- Spatial things -- objectives, spawns, bounds -- are NOT set here. They come
-- only from the markers in the .rbxm, so there is one place to move them.
--
-- Allowed keys: Palette, Terrain, Environment, Vista, Seed.
-- Vista (the intro camera) is generated from the boundary unless you set one:
--     Vista = { pos = { -225, 80, -190 }, look = { 0, 8, 0 }, seconds = 3 },
return {
    Terrain = {
        -- The terrain field under and around the map. Its top is at y = 0.
        GroundMaterial = Enum.Material.Snow,
        GroundColor = Color3.fromRGB(226, 233, 240),
    },
    Palette = {
        Floor = Color3.fromRGB(180, 184, 190),
        Wall = Color3.fromRGB(102, 110, 122),
        Cover = Color3.fromRGB(122, 130, 140),
    },
    Environment = {
        -- Remove Sky to keep whatever sky the place already has.
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
]]

local PRESENTATION_KEYS = { Palette = true, Terrain = true, Environment = true, Vista = true, Seed = true }
local ENVIRONMENT_KEYS = {
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

local function loadLua(text, debugName)
    local ok, chunk = pcall(luau.load, text, {
        debugName = debugName,
        environment = { Color3 = Color3, Enum = Enum, Vector3 = Vector3, math = math, table = table },
    })
    if not ok then
        return nil, tostring(chunk)
    end
    local okRun, value = pcall(chunk)
    if not okRun then
        return nil, tostring(value)
    end
    if type(value) ~= "table" then
        return nil, "it does not return a table"
    end
    return value
end
C.loadLua = loadLua

local function checkPresentation(p, name, errors)
    local function bad(s)
        table.insert(errors, ("%s: %s.presentation.lua: %s"):format(name, name, s))
    end
    for k in p do
        if not PRESENTATION_KEYS[k] then
            bad(
                ("%q is not a presentation setting. Allowed: Palette, Terrain, Environment, Vista, Seed. "):format(
                    tostring(k)
                ) .. "Objectives, spawns and bounds are set by moving markers in Studio."
            )
        end
    end
    if type(p.Terrain) ~= "table" or typeof(p.Terrain.GroundMaterial) ~= "EnumItem" then
        bad("Terrain.GroundMaterial must be an Enum.Material, e.g. Enum.Material.Snow")
    end
    if type(p.Environment) ~= "table" then
        bad("Environment is missing. Copy it back from the default in the map authoring README.")
    else
        for _, k in ENVIRONMENT_KEYS do
            if p.Environment[k] == nil then
                bad(("Environment.%s is missing; the lighting code needs it"):format(k))
            end
        end
    end
    if p.Vista ~= nil and (type(p.Vista) ~= "table" or type(p.Vista.pos) ~= "table" or type(p.Vista.look) ~= "table") then
        bad("Vista must be { pos = { x, y, z }, look = { x, y, z }, seconds = 3 }")
    end
end

-- ===== reading the source =====

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

local function v3list(v)
    return { v.X, v.Y, v.Z }
end

-- Parse the editable source. Returns `authored` (markers as plain numbers, world space),
-- the bake instances, and any errors/warnings about the source itself.
function C.parse(bytes, name)
    local errors, warnings = {}, {}
    local function err(s)
        table.insert(errors, name .. ": " .. s)
    end
    local function warn(s)
        table.insert(warnings, name .. ": " .. s)
    end

    local okRead, roots = pcall(roblox.deserializeModel, bytes)
    if not okRead then
        err("the source file could not be read as a Roblox model (" .. tostring(roots) .. ").")
        return nil, nil, errors, warnings
    end
    local candidates = {}
    for _, r in roots do
        if r:GetAttribute("MapSource") ~= nil then
            table.insert(candidates, r)
        end
    end
    if #candidates == 0 then
        err(
            "this file is not an editable map (no model with a MapSource attribute). "
                .. "In Studio, right-click the '<Name> — EDITABLE' model itself and Save to File. "
                .. "A baked map or a kit piece saved here will not work."
        )
        return nil, nil, errors, warnings
    elseif #candidates > 1 or #roots > 1 then
        err(
            ("the file holds %d top-level objects. Select only the '%s — EDITABLE' model before Save to File."):format(
                #roots,
                name
            )
        )
        return nil, nil, errors, warnings
    end
    local root = candidates[1]
    local declared = root:GetAttribute("MapSource")
    if declared ~= name then
        err(
            ("this file contains the editable map for %q, not %q. You probably saved the wrong model over this file. "):format(
                tostring(declared),
                name
            ) .. ("Restore the previous version with: save_map restore %s"):format(name)
        )
        return nil, nil, errors, warnings
    end
    local format = root:GetAttribute("MapFormat")
    if format ~= nil and format > C.FORMAT then
        err(("the source was made by a newer converter (format %s); update this checkout."):format(tostring(format)))
        return nil, nil, errors, warnings
    end

    local function rel(cf)
        return cf
    end

    local authoring = root:FindFirstChild("Authoring")
    if not authoring then
        err("the Authoring folder is missing, so there are no objectives or spawns. Restore the previous version.")
        return nil, nil, errors, warnings
    end

    -- ---- markers ----
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
        local cf = rel(capture.CFrame)
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
    if #objectives ~= C.CONVERGENCE_OBJECTIVES then
        err(
            ("Convergence needs exactly %d objectives; the map has %d%s. "):format(
                C.CONVERGENCE_OBJECTIVES,
                #objectives,
                #ids > 0 and (" (" .. table.concat(ids, ", ") .. ")") or ""
            )
                .. (
                    #objectives < C.CONVERGENCE_OBJECTIVES
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
            local cf = rel(inst.CFrame)
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
        local cf = rel(box.CFrame)
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

    -- ---- the bake: everything outside Authoring ----
    local bake = roblox.Instance.new("Folder")
    bake.Name = name
    local geometry = root:FindFirstChild("Geometry")
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
        -- Creator Store models often carry scripts, and a script in the bake would run
        -- on the live server. Props never need one.
        if inst:IsA("LuaSourceContainer") then
            err(
                ("%s is a script inside a map piece. Scripts in map geometry would run in the game; "):format(
                    pathOf(inst, bake)
                ) .. "delete it (free models often bring them along)."
            )
        end
        for _, pattern in LEGACY_GUIDE do
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
    if not geometry then
        warn("there is no Geometry folder. Anything outside Authoring still bakes, but keep pieces in Geometry.")
    elseif #geometry:GetChildren() == 0 then
        warn(
            "Geometry is empty. Pieces dragged into Workspace but not into this map model are not saved with it -- "
                .. "drag them onto Geometry in the Explorer."
        )
    end
    authored.PartCount = parts
    return authored, bake, errors, warnings
end

-- ===== generating the map module =====

local ORDER = {
    "Name",
    "Revision",
    "Draft",
    "RequiresBake",
    "Authored",
    "Size",
    "WallHeight",
    "Seed",
    "Finale",
    "Objectives",
    "Spawns",
    "Bounds",
    "RecoveryY",
    "SafetyAlwaysOn",
    "SafePoints",
    "Barrier",
    "InvalidRegions",
    "SafeRegions",
    "Vista",
    "Terrain",
    "Palette",
    "Environment",
    "Center",
    "Mirrored",
    "Decor",
}

local function r3(p)
    return { tonumber(num(p[1])), tonumber(num(p[2])), tonumber(num(p[3])) }
end

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

function C.generate(name, authored, presentation, revision, solids)
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
    for _, side in {
        { "north", { cx, y, b.min[3] - 1.5 }, { lx, 12, 1.5 } },
        { "south", { cx, y, b.max[3] + 1.5 }, { lx, 12, 1.5 } },
        { "west", { b.min[1] - 1.5, y, cz }, { 1.5, 12, lz } },
        { "east", { b.max[1] + 1.5, y, cz }, { 1.5, 12, lz } },
    } do
        if nearGeometry(solids, side[2]) then
            table.insert(barrier, { pos = r3(side[2]), size = r3(side[3]) })
        else
            table.insert(
                warnings,
                ("%s: the ground stops more than 6 studs short of the boundary's %s edge, so there is no "):format(
                    name,
                    side[1]
                ) .. "invisible wall there. Players who walk off are recovered by the boundary. Extend Ground to it if you want a wall."
            )
        end
    end

    local vista = presentation.Vista
        or {
            pos = r3({ b.min[1] + 20, floorY + 80, b.min[3] - 5 }),
            look = r3({ cx, floorY + 8, cz }),
            seconds = 3,
        }

    local layout = {
        Name = name,
        Revision = revision,
        Draft = true,
        RequiresBake = true,
        Authored = {
            Source = "assets/environment/source/" .. name .. ".rbxm",
            Presentation = "assets/environment/source/" .. name .. ".presentation.lua",
            Format = C.FORMAT,
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
    }

    local text = table.concat({
        "-- GENERATED by tools/map.luau from " .. layout.Authored.Source .. " -- do not edit.",
        "--",
        "-- Move objectives, spawns and the boundary in Studio, save the source, then run",
        "--     bash tools/save_map.sh " .. name,
        "-- Sky, lighting and terrain: edit " .. layout.Authored.Presentation .. " instead.",
        "-- See assets/environment/source/README.md.",
        "-- stylua: ignore start",
        "return " .. emit(layout, 0, ORDER),
        "-- stylua: ignore end",
        "",
    }, "\n")
    return text, layout, warnings
end

-- ===== validating a candidate =====

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

-- What is under a point: "ok", or a sentence about why not.
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
        return false, ("floats %.1f studs above %s"):format(p[2] - below, belowName)
    end
    return false, "has nothing under it"
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

local function insideSolid(solids, p)
    for _, box in solids do
        if pointToBox(p, box) == 0 then
            return box.name
        end
    end
    return nil
end

local function inBounds(b, p)
    for i = 1, 3 do
        if p[i] < b.min[i] - 1e-6 or p[i] > b.max[i] + 1e-6 then
            return false
        end
    end
    return true
end

local function close(a, b)
    return math.abs(a - b) <= C.TOLERANCE
end

-- `luaText` and `bakeRoots` are the staged candidates, re-read from disk: this checks
-- exactly what would be installed, not the files that are there now.
function C.validate(name, luaText, bakeRoots, authored, weapons)
    local errors, warnings = {}, {}
    local function err(s)
        table.insert(errors, name .. ": " .. s)
    end
    local function warn(s)
        table.insert(warnings, name .. ": " .. s)
    end

    local layout, loadErr = loadLua(luaText, name)
    if not layout then
        err("the generated map module does not load (" .. tostring(loadErr) .. "). This is a converter bug.")
        return errors, warnings
    end
    for _, k in { "Name", "Size", "WallHeight", "Spawns", "Center", "Mirrored", "Objectives", "Bounds" } do
        if layout[k] == nil then
            err("the generated map module is missing " .. k .. ". This is a converter bug.")
        end
    end
    if #errors > 0 then
        return errors, warnings
    end

    local solids, parts = Baked.fromRoots(bakeRoots, Validate)

    -- helpers must never ship
    for _, root in bakeRoots do
        for _, inst in root:GetDescendants() do
            if inst:GetAttribute("AuthoringHelper") ~= nil or inst:GetAttribute("Role") ~= nil then
                err("the playable bake contains authoring marker " .. inst:GetFullName() .. ". This is a converter bug.")
            end
            for _, pattern in LEGACY_GUIDE do
                if inst.Name:match(pattern) then
                    err("the playable bake contains guide marker " .. inst:GetFullName() .. ".")
                    break
                end
            end
        end
    end

    -- generated values must be the authored ones
    if #layout.Objectives ~= #authored.Objectives then
        err("generated objective count differs from the source. This is a converter bug.")
    else
        for i, o in authored.Objectives do
            local g = layout.Objectives[i]
            if
                g.Id ~= o.Id
                or not (close(g.pos[1], o.pos[1]) and close(g.pos[2], o.pos[2]) and close(g.pos[3], o.pos[3]))
                or not close(g.radius, o.radius)
                or not close(g.halfHeight, o.halfHeight)
            then
                err(("generated data for objective %s does not match its marker. This is a converter bug."):format(o.Id))
            end
        end
    end
    for _, team in { "Blue", "Red" } do
        local a, g = authored.Spawns[team], layout.Spawns[team] or {}
        if #a ~= #g then
            err(("generated %s spawn count differs from the source. This is a converter bug."):format(team))
        else
            for i, s in a do
                if not (close(g[i][1], s.pos[1]) and close(g[i][2], s.pos[2]) and close(g[i][3], s.pos[3])) then
                    err(("generated data for %s does not match its marker. This is a converter bug."):format(s.Where))
                end
            end
        end
    end
    for _, k in { "min", "max" } do
        for i = 1, 3 do
            if not close(layout.Bounds[k][i], authored.Bounds[k][i]) then
                err("generated bounds do not match the Map Boundary. This is a converter bug.")
            end
        end
    end
    if #parts ~= authored.PartCount then
        err(("the bake has %d parts but the source has %d outside Authoring."):format(#parts, authored.PartCount))
    end

    -- ---- gameplay placement ----
    local b = layout.Bounds
    local cx, cz = (b.min[1] + b.max[1]) / 2, (b.min[3] + b.max[3]) / 2
    if math.sqrt(cx * cx + cz * cz) > 50 then
        warn(
            ("the map's centre is at (%.0f, %.0f), %.0f studs from the world origin. Players spawn facing the origin "):format(
                cx,
                cz,
                math.sqrt(cx * cx + cz * cz)
            ) .. "and the terrain is centred on it. If you moved the whole map by accident, move it back."
        )
    end
    for _, o in authored.Objectives do
        if not inBounds(b, o.pos) then
            err(("%s is outside the Map Boundary. Move it inside, or enlarge the boundary."):format(o.Where))
        end
        if o.radius < 4 then
            err(("%s has a capture radius of %.1f studs; players could barely stand in it. Scale the Capture cylinder up."):format(o.Where, o.radius))
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
        local ok, why = support(layout, solids, o.pos)
        if not ok then
            err(("%s %s. Drag it down onto a floor (the bottom of the cylinder is the floor point)."):format(o.Where, why))
        end
        local buried = insideSolid(solids, { o.pos[1], o.pos[2] + 1, o.pos[3] })
        if buried then
            err(("%s is sunk into %s. Raise it so the cylinder's bottom sits on the floor."):format(o.Where, buried))
        end
        -- other floors inside the capture height (it extends as far below as above)
        for _, box in solids do
            local a = box.aabb
            if o.pos[1] >= a.min.x and o.pos[1] <= a.max.x and o.pos[3] >= a.min.z and o.pos[3] <= a.max.z then
                local top = a.max.y
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
                        ) .. "Shorten the cylinder or raise the objective if that floor is a different level."
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
            local ok, why = support(layout, solids, s.pos)
            if not ok then
                err(("%s %s. Drag it onto a floor."):format(s.Where, why))
            end
            local blocked = insideSolid(solids, { s.pos[1], s.pos[2] + 2.5, s.pos[3] })
            if blocked then
                err(("%s is inside %s; a player would spawn in it. Move the pad into open space."):format(s.Where, blocked))
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

    -- ---- Convergence finale: every eligible objective must be able to host the final fight ----
    local eligible = layout.Finale and layout.Finale.EligibleIds or {}
    if #layout.Objectives == C.CONVERGENCE_OBJECTIVES then
        if #eligible < 2 then
            err(
                ("only %d objective(s) have FinaleEligible = true; the finale needs at least 2 (the template makes all 3 eligible)."):format(
                    #eligible
                )
            )
        else
            for final = 1, #eligible do
                local plan, why = FinalePlan.create(name .. "#validate", layout.Objectives, layout.Finale, function(n)
                    return math.min(final, n)
                end)
                if not plan then
                    err("the finale settings are rejected: " .. tostring(why))
                    break
                end
            end
        end
    end

    -- ---- the shared map rules (the same check check_maps runs) ----
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
                ) .. "Fine while designing; before the map goes public, check both teams' travel times in a playtest."
            )
        end
    end
    return errors, warnings, layout, parts
end

function C.revision(sourceBytes, presentationText)
    local h = serde.hash("sha256", sourceBytes .. "\0" .. presentationText .. "\0" .. tostring(C.FORMAT))
    return "src-" .. h:sub(1, 10)
end

-- Full candidate build, in memory. Nothing is written.
function C.build(root, name)
    local P = C.paths(root, name)
    local result = { errors = {}, warnings = {}, paths = P }
    if not fs.isFile(P.source) then
        table.insert(
            result.errors,
            ("%s: there is no editable source at %s. Save the map model there from Studio (right-click > Save to File), "):format(
                name,
                P.relSource
            ) .. ("or create a new one with: bash tools/save_map.sh new %s"):format(name)
        )
        return result
    end
    local sourceBytes = fs.readFile(P.source)
    local presentationText = fs.isFile(P.presentation) and fs.readFile(P.presentation) or nil
    result.presentationIsNew = presentationText == nil
    presentationText = presentationText or C.PRESENTATION_DEFAULT
    result.presentationText = presentationText
    result.revision = C.revision(sourceBytes, presentationText)

    local presentation, pErr = loadLua(presentationText, name .. ".presentation")
    if not presentation then
        table.insert(
            result.errors,
            ("%s: %s has a mistake and cannot be read: %s"):format(name, P.relPresentation, tostring(pErr))
        )
        return result
    end
    checkPresentation(presentation, name, result.errors)

    local authored, bake, errors, warnings = C.parse(sourceBytes, name)
    for _, e in errors do
        table.insert(result.errors, e)
    end
    for _, w in warnings do
        table.insert(result.warnings, w)
    end
    if #result.errors > 0 then
        return result
    end
    result.authored = authored
    result.bakeBytes = roblox.serializeModel({ bake })
    local solids = Baked.fromRoots({ bake }, Validate)
    local text, _, genWarnings = C.generate(name, authored, presentation, result.revision, solids)
    result.luaText = text
    for _, w in genWarnings do
        table.insert(result.warnings, w)
    end
    return result
end

-- A fresh template source, for `new`.
function C.templateBytes(name)
    return roblox.serializeModel({ Template.build(name) })
end

-- Re-read what is installed and say whether it is what the source would produce now.
-- Catches a failed conversion being mistaken for a successful one, and hand edits.
function C.freshness(root, name)
    local P = C.paths(root, name)
    local problems = {}
    local candidate = C.build(root, name)
    if #candidate.errors > 0 then
        table.insert(
            problems,
            ("the source does not convert right now (%d problem(s)); the installed version is from an older save"):format(
                #candidate.errors
            )
        )
        return problems, candidate
    end
    if not fs.isFile(P.map) then
        table.insert(problems, P.relMap .. " is missing")
    elseif fs.readFile(P.map) ~= candidate.luaText then
        table.insert(problems, P.relMap .. " differs from what the source generates (stale, or edited by hand)")
    end
    if not fs.isFile(P.bake) then
        table.insert(problems, P.relBake .. " is missing")
    elseif fs.readFile(P.bake) ~= candidate.bakeBytes then
        table.insert(problems, P.relBake .. " differs from what the source generates (stale, or edited by hand)")
    end
    if candidate.presentationIsNew then
        table.insert(problems, P.relPresentation .. " is missing")
    end
    return problems, candidate
end

return C
