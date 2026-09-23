-- Build gate: a baked map must contain every solid its source data describes.
--
-- Baking a map means letting MapService build it for real in Studio and saving
-- workspace.Map to a file. That is deliberate: re-implementing the builder here to
-- produce the bake would mean two builders that must agree, which is the drift this
-- whole exercise is meant to remove. Lune's job is to check the result, not make it.
--
-- So this asks one question. For every solid the map data says should exist, is there a
-- part in the baked model at that position and size? Extra parts are expected and fine --
-- the bake also carries decor, markers, lights, facade meshes and loaded props, none of
-- which the validator models. A MISSING solid means the bake is stale or incomplete, and
-- that is the failure worth catching: a wall that is in the source and not in the file.
--
--     lune run tools/check_bake.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Map data uses these as globals. Lune has no Roblox globals, so publish them first.
Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local Validate = require("../src/shared/Maps/Validate")

local BAKE_DIR = "assets/environment/baked"
local TOLERANCE = 0.1 -- studs; both sides come from the same numbers, so this is rounding only

-- Derived maps require their base by instance path; give them a `script` to walk and a
-- `require` that hands back an already-loaded table, the same way check_maps does.
local preloaded = { Forest = require("../src/shared/Maps/Forest") }
preloaded.Parent = { MapArt = { AlpineFortress = require("../src/shared/MapArt/AlpineFortress") } }
script = { Parent = preloaded }
local luneRequire = require
require = function(target)
    if type(target) == "table" then
        return target
    end
    return luneRequire(target)
end

-- Match on shape and place, not on name. MapService prefixes a mirrored pair "Red_"/"Blue_"
-- while the validator models the unmirrored copy without a prefix, so names disagree by
-- design. Position and size do not.
--
-- Matched within a tolerance rather than by a rounded key. Roblox stores these as 32-bit
-- floats, so a value that is 5.7 in the source comes back as 5.699999809, and any scheme
-- that buckets by rounding puts those two on opposite sides of a boundary now and then.
-- A complete bake reported five missing walls before this was a range test.
local function near(a, b)
    return math.abs(a - b) <= TOLERANCE
end

local function matches(part, box)
    return near(part.px, box.c.x)
        and near(part.py, box.c.y)
        and near(part.pz, box.c.z)
        and near(part.sx, box.h.x * 2)
        and near(part.sy, box.h.y * 2)
        and near(part.sz, box.h.z * 2)
end

if not fs.isDir(BAKE_DIR) then
    print("no " .. BAKE_DIR .. " directory yet; nothing baked")
    process.exit(0)
end

local checked, failures = 0, 0
local files = fs.readDir(BAKE_DIR)
table.sort(files)

for _, file in files do
    if not (file:match("%.rbxmx$") or file:match("%.rbxm$")) then
        continue
    end
    local mapName = file:gsub("%.rbxmx?$", "")
    local ok, layout = pcall(luneRequire, "../src/shared/Maps/" .. mapName)
    if not ok then
        print(("SKIP  %s -- no map module named %s"):format(file, mapName))
        continue
    end

    local present = {}
    local parts = 0
    for _, root in roblox.deserializeModel(fs.readFile(BAKE_DIR .. "/" .. file)) do
        local function walk(inst)
            if inst:IsA("BasePart") then
                -- Lune only hands back properties the file actually stored, and a part
                -- saved with a CFrame has no separate Position to read. Ask for both and
                -- skip anything that answers neither rather than dying on one odd part.
                local okCf, cf = pcall(function()
                    return inst.CFrame
                end)
                local okSize, size = pcall(function()
                    return inst.Size
                end)
                local pos = okCf and cf.Position or nil
                if not pos then
                    local okPos, raw = pcall(function()
                        return inst.Position
                    end)
                    pos = okPos and raw or nil
                end
                if pos and okSize then
                    parts += 1
                    table.insert(present, {
                        px = pos.X,
                        py = pos.Y,
                        pz = pos.Z,
                        sx = size.X,
                        sy = size.Y,
                        sz = size.Z,
                    })
                end
            end
            for _, child in inst:GetChildren() do
                walk(child)
            end
        end
        walk(root)
    end

    local missing = {}
    local expected = Validate.solids(layout)
    for _, box in expected do
        local found = false
        for _, part in present do
            if matches(part, box) then
                found = true
                break
            end
        end
        if not found then
            table.insert(missing, ("%s at (%.1f, %.1f, %.1f)"):format(box.name, box.c.x, box.c.y, box.c.z))
        end
    end

    checked += 1
    if #missing > 0 then
        failures += 1
        print(("FAIL  %-18s %d parts baked, %d of %d source solids missing"):format(
            file,
            parts,
            #missing,
            #expected
        ))
        for i, item in missing do
            if i > 12 then
                print(("        ... and %d more"):format(#missing - 12))
                break
            end
            print("        missing " .. item)
        end
    else
        print(("OK    %-18s %d parts baked, all %d source solids present"):format(file, parts, #expected))
    end
end

if checked == 0 then
    print("no baked maps found")
    process.exit(0)
end
print(("\n%d baked maps checked, %d failed"):format(checked, failures))
if failures > 0 then
    process.exit(1)
end
