-- Design data -> editable map source.
--
--     lune run tools/map_generate.luau <Name>
--
-- Reads  assets/environment/source/<Name>.design.luau   (the design: boxes, walls, ramps, markers)
-- Writes assets/environment/source/<Name>.rbxm          (the same editable model Studio saves)
--
-- Then `bash tools/save_map.sh <Name>` converts and checks it like any authored map, and
-- `lune run tools/measure_map.luau <Name>` measures lanes, chokes and sightlines.
--
-- The design is written for one half of the map. Every part is copied to the other half
-- at -x unless it says `mirror = false`, so both teams get the same floor plan. A look may
-- carry an `east` table that changes the colour or material of the copy: the two sides can
-- be dressed differently, but nothing a player collides with differs.
--
-- Kinds:
--   box    min, max ({x, y, z})                       any block
--   cover  min, max ({x, z}), h, y0?                  a block standing on the floor
--          `windows = { sill, head, bay, pier, look }` makes each run a solid wall with clear panes
--   wall   axis ("x": constant x, runs along z; "z": constant z, runs along x), at, from, to,
--          y0, y1, thick?, doors = { { at, width, top, bottom? } }
--          split into pieces round each door, with a lintel above and a sill below
--   ramp   low, high ({x, y, z} on the walking surface), width
--          a sloped deck, with the space beneath filled so nobody gets under it
--   light  at, range, brightness, color?
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Template = require("./mapauthor/template")

local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local Instance = roblox.Instance

local name = process.args[1]
if not name then
    print("usage: lune run tools/map_generate.luau <Name>")
    process.exit(1)
end
local designPath = ("assets/environment/source/%s.design.luau"):format(name)
local sourcePath = ("assets/environment/source/%s.rbxm"):format(name)
if not fs.isFile(designPath) then
    print("no design at " .. designPath)
    process.exit(1)
end
local design = luau.load(fs.readFile(designPath), { debugName = designPath })()
assert(design.name == name, "the design's name does not match the file name")

local RAMP_MAX_DEGREES = 32 -- Validate.RULES.RampAngleMax: steeper stalls characters
local problems = {}

local function folder(parent, folderName, class)
    local f = Instance.new(class or "Folder")
    f.Name = folderName
    f.Parent = parent
    return f
end

local root = Instance.new("Model")
root.Name = name .. " — EDITABLE"
root:SetAttribute("MapSource", name)
root:SetAttribute("MapFormat", Template.FORMAT)
root:SetAttribute("GeneratedFrom", designPath)
root.WorldPivotData = CFrame.new()
local ground = folder(root, "Ground", "Model")
local geometry = folder(root, "Geometry")
local groups = { Ground = ground }
local function groupFor(groupName)
    if not groups[groupName] then
        groups[groupName] = folder(geometry, groupName, "Model")
    end
    return groups[groupName]
end

local count = 0

local function resolve(lookName, side)
    local look = design.looks[lookName]
    assert(look, "unknown look " .. tostring(lookName))
    local out = table.clone(look)
    if side == "E" and look.east then
        for k, v in look.east do
            out[k] = v
        end
    end
    return out
end

local function style(part, look)
    part.Color = Color3.fromRGB(look.color[1], look.color[2], look.color[3])
    part.Material = Enum.Material[look.material or "SmoothPlastic"]
    part.Transparency = look.transparency or 0
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
end

local function newPart(parent, partName, collide)
    local p = Instance.new("Part")
    p.Name = partName
    p.Anchored = true
    p.CanCollide = collide
    p.CanQuery = collide
    p.CanTouch = false
    p.CastShadow = collide
    p.Parent = parent
    count += 1
    return p
end

-- Props wait here until the Authoring folder exists. An asset the design names but that
-- has no uploaded id yet is skipped and listed, so a map can be designed ahead of its art.
local pendingProps, missingAssets, notUploaded = {}, {}, {}
local registry = fs.isFile("src/shared/AssetRegistry.json")
        and serde.decode("json", fs.readFile("src/shared/AssetRegistry.json"))
    or {}
local function queueProp(propName, assetName, pos, yaw, size, fit, hides)
    local asset = (design.assets or {})[assetName]
    -- `registry` names an entry in src/shared/AssetRegistry.json; the marker carries that
    -- name and the game looks the id up. Only an uploaded entry counts as placeable.
    local ref = asset and asset.id
    if asset and asset.registry then
        local entry = registry[asset.registry]
        ref = entry and entry.assetId and asset.registry or nil
    end
    if not ref then
        missingAssets[assetName] = (missingAssets[assetName] or 0) + 1
        -- Built but not uploaded: the game cannot draw it, the preview can.
        if asset and asset.glb then
            table.insert(
                notUploaded,
                { name = propName, pos = pos, yaw = yaw, fit = fit, glb = asset.glb, hides = hides }
            )
        end
        return false
    end
    table.insert(pendingProps, { name = propName, id = ref, pos = pos, yaw = yaw, size = size, fit = fit })
    return true
end

-- What each touchable block is going to be. One row per design entry; the mirror copy
-- adds a footprint to the same row.
local inventory, inventoryOrder = {}, {}
local function assetStatus(assetName)
    local asset = (design.assets or {})[assetName]
    if not asset then
        return "undecided"
    end
    local entry = asset.registry and registry[asset.registry]
    if asset.id or (entry and entry.assetId) then
        return "in game"
    elseif asset.glb and fs.isFile(asset.glb) then
        return "built, not uploaded"
    end
    return "to make"
end
local function noteBlock(spec, partName, min, max, size)
    local row = inventory[spec.name]
    if not row then
        local shell = spec.shell
        local asset = shell and (design.assets or {})[shell.asset]
        local pieces = shell and shell.pieces or 1
        local long = math.max(size[1], size[3])
        row = {
            name = spec.name,
            becomes = spec.becomes or (asset and asset.is),
            asset = shell and shell.asset,
            status = shell and assetStatus(shell.asset) or (spec.finish and "finish only" or "undecided"),
            finish = spec.finish,
            size = size,
            pieces = pieces,
            piece = { long / pieces, math.min(size[1], size[3]), size[2] },
            footprints = {},
        }
        if not row.becomes then
            row.status = "undecided"
        end
        inventory[spec.name] = row
        table.insert(inventoryOrder, row)
    end
    table.insert(row.footprints, { min[1], min[3], max[1], max[3], partName })
end

-- One axis-aligned block. `side` is "W", "E" or nil (centre).
local function block(spec, partName, min, max, side, lookName, collide)
    for i = 1, 3 do
        if max[i] - min[i] <= 0 then
            table.insert(problems, ("%s has no size on axis %d"):format(partName, i))
            return nil
        end
    end
    local look = resolve(lookName or spec.look, side)
    local p = newPart(groupFor(spec.group or (collide and "Structure" or "Dressing")), partName, collide)
    p.Size = Vector3.new(max[1] - min[1], max[2] - min[2], max[3] - min[3])
    p.CFrame = CFrame.new((min[1] + max[1]) / 2, (min[2] + max[2]) / 2, (min[3] + max[3]) / 2)
    style(p, look)
    -- Every block a player can touch is listed in the inventory with what it becomes in
    -- the finished scene, so no anonymous box survives to the art pass.
    local size = { max[1] - min[1], max[2] - min[2], max[3] - min[3] }
    local shell = spec.shell
    if collide and not spec.structure and spec.kind ~= "wall" and spec.kind ~= "ramp" then
        noteBlock(spec, partName, min, max, size)
    end
    -- A shell draws an uploaded model over this block. The block stays exactly as it is
    -- for collision, bullets and the measurements, and turns invisible; the model has no
    -- collision. `pieces` repeats the model along the block's longer side. The model is
    -- turned so its long side (`long` on the asset, x unless stated) runs along the block's.
    if shell and collide then
        local asset = (design.assets or {})[shell.asset] or {}
        local alongX = size[1] >= size[3]
        local yaw = shell.yaw
        if yaw == nil then
            yaw = ((asset.long or "x") == "x") == alongX and 0 or 90
        end
        yaw = (side == "E" and -1 or 1) * yaw + (shell.flip and 180 or 0)
        local pieces = shell.pieces or 1
        local length = math.max(size[1], size[3]) / pieces
        local placed = true
        for i = 1, pieces do
            local offset = (i - 0.5) * length - math.max(size[1], size[3]) / 2
            local base = { (min[1] + max[1]) / 2, min[2], (min[3] + max[3]) / 2 }
            base[alongX and 1 or 3] += offset
            local marker = alongX and { length, size[2], size[3] } or { size[1], size[2], length }
            local label = pieces > 1 and (" Prop " .. i) or " Prop"
            placed = queueProp(partName .. label, shell.asset, base, yaw, marker, shell.fit or length, partName)
                and placed
        end
        if placed then
            p.Transparency = 1
            p.CastShadow = false
            return p
        end
    end
    -- The band is the side's colour on top of cover: readable at a glance, and it is how
    -- a player knows which half of a mirrored map they are in.
    if look.band and collide then
        local accent = resolve("Accent", side)
        local band = newPart(groupFor("Dressing"), partName .. "Band", false)
        band.Size = Vector3.new(max[1] - min[1] + 0.2, 0.3, max[3] - min[3] + 0.2)
        band.CFrame = CFrame.new((min[1] + max[1]) / 2, max[2] + 0.15, (min[3] + max[3]) / 2)
        style(band, accent)
    end
    return p
end

local function mirrorBox(min, max)
    return { -max[1], min[2], min[3] }, { -min[1], max[2], max[3] }
end

-- Run `emit(side, flipX)` for the west copy and, unless the part is a centre piece, the east.
local function eachSide(spec, emit)
    if spec.mirror == false then
        emit(nil, false)
    else
        emit("W", false)
        emit("E", true)
    end
end

local function suffix(side)
    return side and (" " .. side) or ""
end

local builders = {}

function builders.box(spec)
    local collide = spec.collide ~= false
    eachSide(spec, function(side, flip)
        local min, max = spec.min, spec.max
        if flip then
            min, max = mirrorBox(min, max)
        end
        block(spec, spec.name .. suffix(side), min, max, side, nil, collide)
    end)
end

function builders.cover(spec)
    local y0 = spec.y0 or 0
    builders.box({
        name = spec.name,
        group = spec.group or "Cover",
        look = spec.look,
        mirror = spec.mirror,
        shell = spec.shell,
        becomes = spec.becomes,
        finish = spec.finish,
        structure = spec.structure,
        min = { spec.min[1], y0, spec.min[2] },
        max = { spec.max[1], y0 + spec.h, spec.max[2] },
    })
end

function builders.wall(spec)
    local half = (spec.thick or 2) / 2
    local doors = table.clone(spec.doors or {})
    table.sort(doors, function(a, b)
        return a.at < b.at
    end)
    -- (u0, u1) along the wall, (y0, y1) up: one piece
    local function piece(side, flip, label, u0, u1, y0, y1, lookName)
        if u1 - u0 <= 0 or y1 - y0 <= 0 then
            return
        end
        local min, max
        if spec.axis == "z" then
            min, max = { u0, y0, spec.at - half }, { u1, y1, spec.at + half }
        else
            min, max = { spec.at - half, y0, u0 }, { spec.at + half, y1, u1 }
        end
        if flip then
            min, max = mirrorBox(min, max)
        end
        block(spec, spec.name .. label .. suffix(side), min, max, side, lookName, true)
    end
    -- A run of wall between doors. With `windows` it is a solid wall with clear panes:
    -- a sill, a head, and piers between bays, so it reads as a wall you can see out of
    -- rather than a sheet of tinted glass. The panes are solid to players and bullets.
    local function run(side, flip, label, u0, u1)
        local w = spec.windows
        if not w or u1 - u0 < (w.pier or 4) + 4 then
            piece(side, flip, label, u0, u1, spec.y0, spec.y1)
            return
        end
        local sill, head, pier = spec.y0 + (w.sill or 3), spec.y0 + (w.head or 13), w.pier or 4
        piece(side, flip, label .. " sill", u0, u1, spec.y0, sill)
        piece(side, flip, label .. " head", u0, u1, head, spec.y1)
        local bays = math.max(1, math.floor((u1 - u0) / (w.bay or 18) + 0.5))
        local length = (u1 - u0) / bays
        for k = 1, bays do
            local b0 = u0 + (k - 1) * length
            piece(side, flip, ("%s pier %da"):format(label, k), b0, b0 + pier / 2, sill, head)
            piece(
                side,
                flip,
                ("%s pane %d"):format(label, k),
                b0 + pier / 2,
                b0 + length - pier / 2,
                sill,
                head,
                w.look or "Window"
            )
            piece(side, flip, ("%s pier %db"):format(label, k), b0 + length - pier / 2, b0 + length, sill, head)
        end
    end
    eachSide(spec, function(side, flip)
        local cursor = spec.from
        for i, door in doors do
            local d0, d1 = door.at - door.width / 2, door.at + door.width / 2
            if d0 < cursor or d1 > spec.to then
                table.insert(problems, ("%s: door %d overlaps a neighbour or the wall's end"):format(spec.name, i))
            end
            run(side, flip, " " .. i, cursor, d0)
            piece(side, flip, " lintel " .. i, d0, d1, door.top, spec.y1)
            piece(side, flip, " sill " .. i, d0, d1, spec.y0, door.bottom or spec.y0)
            cursor = d1
        end
        run(side, flip, " " .. (#doors + 1), cursor, spec.to)
    end)
end

function builders.ramp(spec)
    local low, high = spec.low, spec.high
    local dx, dy, dz = high[1] - low[1], high[2] - low[2], high[3] - low[3]
    local run = math.sqrt(dx * dx + dz * dz)
    local angle = math.deg(math.atan2(dy, run))
    if angle > RAMP_MAX_DEGREES then
        table.insert(
            problems,
            ("%s climbs at %.1f degrees; over %d stalls characters"):format(spec.name, angle, RAMP_MAX_DEGREES)
        )
    end
    if math.abs(dx) > 1e-6 and math.abs(dz) > 1e-6 then
        table.insert(problems, spec.name .. " must run along x or z, not diagonally")
        return
    end
    local alongX = math.abs(dx) > 1e-6
    local half = spec.width / 2
    eachSide(spec, function(side, flip)
        local s = flip and -1 or 1
        local lx, hx = low[1] * s, high[1] * s
        local length = math.sqrt(run * run + dy * dy)
        local f = Vector3.new((hx - lx) / length, dy / length, dz / length)
        local right = f:Cross(Vector3.new(0, 1, 0)).Unit
        local up = right:Cross(f)
        local mid = Vector3.new((lx + hx) / 2, (low[2] + high[2]) / 2, (low[3] + high[3]) / 2)
        local look = resolve(spec.look, side)
        local deck = newPart(groupFor("Structure"), spec.name .. suffix(side), true)
        deck.Size = Vector3.new(spec.width, 1, length)
        deck.CFrame = CFrame.fromMatrix(mid - up * 0.5, right, up)
        style(deck, look)
        -- Fill beneath in 4-stud steps, each as tall as the deck's underside at its low end.
        local steps = math.floor(run / 4)
        for i = 1, steps - 1 do
            local d0, d1 = i * 4, math.min((i + 1) * 4, run)
            local top = low[2] + dy * d0 / run - 1.3
            if top - low[2] >= 1 then
                local a0 = (alongX and lx or low[3]) + (alongX and (hx - lx) or dz) * d0 / run
                local a1 = (alongX and lx or low[3]) + (alongX and (hx - lx) or dz) * d1 / run
                local lo, hi = math.min(a0, a1), math.max(a0, a1)
                local min, max
                if alongX then
                    min, max = { lo, low[2], low[3] - half }, { hi, top, low[3] + half }
                else
                    min, max = { lx - half, low[2], lo }, { lx + half, top, hi }
                end
                block(spec, ("%s fill %d%s"):format(spec.name, i, suffix(side)), min, max, side, nil, true)
            end
        end
    end)
end

function builders.light(spec)
    eachSide(spec, function(side, flip)
        local x = flip and -spec.at[1] or spec.at[1]
        local lamp = newPart(groupFor("Lights"), spec.name .. suffix(side), false)
        lamp.Size = Vector3.new(3, 0.4, 3)
        lamp.CFrame = CFrame.new(x, spec.at[2], spec.at[3])
        style(lamp, resolve(spec.look or "Lamp", side))
        local light = Instance.new("PointLight")
        light.Range = spec.range or 40
        light.Brightness = spec.brightness or 1.5
        local c = spec.color or { 255, 236, 204 }
        light.Color = Color3.fromRGB(c[1], c[2], c[3])
        light.Shadows = false
        light.Parent = lamp
    end)
end

for _, spec in design.parts do
    local build = builders[spec.kind]
    if build then
        build(spec)
    else
        table.insert(problems, ("%s has unknown kind %q"):format(tostring(spec.name), tostring(spec.kind)))
    end
end

-- ===== markers: the same ones the blank template makes =====
local authoring = folder(root, "Authoring")
authoring:SetAttribute("AuthoringHelper", true)
local objectives = folder(authoring, "Objectives")
for _, o in design.objectives do
    local marker = Template.objective(objectives, o.id, o.pos, o.radius, o.halfHeight)
    marker:SetAttribute("Label", o.label or o.id)
    if o.finale == false then
        marker:SetAttribute("FinaleEligible", false)
    end
end
local spawns = folder(authoring, "Spawns")
local blue, red = folder(spawns, "Blue"), folder(spawns, "Red")
for i, pos in design.spawns do
    Template.spawn(blue, "Blue", "Spawn " .. i, pos)
    Template.spawn(red, "Red", "Spawn " .. i, { -pos[1], pos[2], pos[3] })
end
Template.bounds(authoring, design.bounds.min, design.bounds.max)

-- Standalone props, then every prop as a marker. `at` is the point it stands on.
for _, spec in design.props or {} do
    eachSide(spec, function(side, flip)
        local s = flip and -1 or 1
        local size = spec.box or { spec.fit or 4, spec.fit or 4, spec.fit or 4 }
        queueProp(
            spec.name .. suffix(side),
            spec.asset,
            { spec.at[1] * s, spec.at[2], spec.at[3] },
            s * (spec.yaw or 0),
            size,
            spec.fit
        )
    end)
end
if #pendingProps > 0 then
    local propFolder = folder(authoring, "Props")
    for _, p in pendingProps do
        Template.prop(propFolder, p.name, p.id, p.pos, p.yaw, p.size, p.fit)
    end
end
for assetName, uses in missingAssets do
    print(("%s: asset %q has no uploaded id yet; %d placement(s) left as plain blocks."):format(name, assetName, uses))
end

if #problems > 0 then
    print(("%s: the design has %d problem(s); nothing written."):format(name, #problems))
    for _, p in problems do
        print("  " .. p)
    end
    process.exit(1)
end

fs.writeFile(sourcePath, roblox.serializeModel({ root }))
-- What the preview should draw that the game cannot yet: read by tools/measure_map.luau.
local previewDir = "docs/design/" .. name:lower()
if not fs.isDir(previewDir) then
    fs.writeDir(previewDir)
end
fs.writeFile(previewDir .. "/props-not-uploaded.json", serde.encode("json", notUploaded))
-- The block inventory: read by tools/map_blocks.py, which draws it.
local wanted = {}
for key, asset in design.assets or {} do
    wanted[key] = { is = asset.is, want = asset.want, registry = asset.registry, status = assetStatus(key) }
end
fs.writeFile(
    previewDir .. "/blocks.json",
    serde.encode("json", { map = name, blocks = inventoryOrder, assets = wanted })
)
local undecided = 0
for _, row in inventoryOrder do
    if row.status == "undecided" then
        undecided += 1
        print(("%s: block %q has no `becomes`: say what it is in the finished scene."):format(name, row.name))
    end
end
print(("%s: wrote %s (%d parts) from %s"):format(name, sourcePath, count, designPath))
print(
    ("%s: %d kinds of block, %d undecided. Sheet: python tools/map_blocks.py %s"):format(
        name,
        #inventoryOrder,
        undecided,
        name
    )
)
print(("next: bash tools/save_map.sh %s"):format(name))
