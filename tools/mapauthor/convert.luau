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
local MapAuthoring = require("../../src/shared/MapAuthoring")

local C = {}

C.FORMAT = MapAuthoring.FORMAT
-- Positions are written to 3 decimals. Authored and generated values must agree to
-- this, which is looser than the rounding and far tighter than anything a player sees.
C.TOLERANCE = 0.01
C.CONVERGENCE_OBJECTIVES = MapAuthoring.CONVERGENCE_OBJECTIVES

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

local num = MapAuthoring.num
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
C.emit = emit

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
-- The marker reading, layout generation and placement checks are in
-- src/shared/MapAuthoring.lua, which the game also uses to play a map live in Studio.
-- What stays here is what only a file needs: finding the root, serialising, and checking
-- the staged candidate against what was authored.

-- Parse the editable source file. Returns `authored` (markers as plain numbers, world
-- space), the bake instances, and any errors/warnings about the source itself.
function C.parse(bytes, name)
    local errors, warnings = {}, {}
    local function err(s)
        table.insert(errors, name .. ": " .. s)
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

    local authored, e1, w1 = MapAuthoring.readMarkers(root, name)
    local bake, parts, e2, w2 = MapAuthoring.bake(root, name, roblox.Instance)
    for _, list in { e1, e2 } do
        for _, e in list do
            table.insert(errors, e)
        end
    end
    for _, list in { w1, w2 } do
        for _, w in list do
            table.insert(warnings, w)
        end
    end
    if authored then
        authored.PartCount = parts
    end
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

function C.generate(name, authored, presentation, revision, solids)
    local layout, warnings = MapAuthoring.generate(name, authored, presentation, revision, solids)
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
            for _, pattern in MapAuthoring.LEGACY_GUIDE do
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

    -- every eligible objective must be able to host the final fight
    local eligible = layout.Finale and layout.Finale.EligibleIds or {}
    if #layout.Objectives == C.CONVERGENCE_OBJECTIVES and #eligible >= 2 then
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

    -- placement and the shared map rules: the same checks the game runs live in Studio
    local e2, w2 = MapAuthoring.check(name, layout, solids, authored, Validate, weapons)
    for _, e in e2 do
        table.insert(errors, e)
    end
    for _, w in w2 do
        table.insert(warnings, w)
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
