--!strict
-- Every built asset must carry an appraisal, and the appraisal must say what the
-- asset is FOR. Skipping that step is what cost four rounds of rework on the Snow
-- Fortress horizon: a top-down scan of a flat ice plain was processed, decimated,
-- exaggerated, tiled, uploaded three times and placed as a mountain range before
-- anyone measured whether it could be one.
--
-- Produce a record with:
--   blender -b -noaudio --python tools/blender/appraise_asset.py -- \
--       --source "<source file>" --record assets/<kind>/<name>/appraisal.json
-- then fill in `decision`. See docs/design/ASSET_INTAKE_AND_LESSONS.md.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

-- Directories whose children are asset packages. Generated output (weapons, skins,
-- the runtime art slice, rendered skyboxes) has no external source to appraise.
local ROOTS = { "assets/models", "assets/scenery" }
local REQUIRED = { "tool", "source", "sourceSha256", "measurements", "verdict" }

local failures = 0
local checked = 0

local function fail(package: string, message: string)
    failures += 1
    print(("FAIL  %-34s %s"):format(package, message))
end

local function hasBuiltMesh(dir: string): boolean
    for _, entry in fs.readDir(dir) do
        local path = dir .. "/" .. entry
        if fs.isFile(path) and (entry:sub(-4) == ".glb" or entry:sub(-4) == ".fbx") then
            return true
        end
        if fs.isDir(path) and entry == "exports" then
            for _, nested in fs.readDir(path) do
                if nested:sub(-4) == ".glb" or nested:sub(-4) == ".fbx" then
                    return true
                end
            end
        end
    end
    return false
end

local function checkPackage(dir: string)
    checked += 1
    local recordPath = dir .. "/appraisal.json"
    if not fs.isFile(recordPath) then
        fail(dir, "no appraisal.json -- run tools/blender/appraise_asset.py --record")
        return
    end
    local ok, record = pcall(function()
        return serde.decode("json", fs.readFile(recordPath))
    end)
    if not ok or type(record) ~= "table" then
        fail(dir, "appraisal.json is not readable JSON")
        return
    end
    for _, key in REQUIRED do
        if record[key] == nil then
            fail(dir, ("appraisal.json is missing %q"):format(key))
            return
        end
    end
    local decision = record.decision
    if type(decision) ~= "string" or decision:gsub("%s", "") == "" then
        fail(dir, "appraisal.json has no `decision` -- state what this asset is for")
        return
    end
    local measurements = record.measurements
    if type(measurements) ~= "table" or type(measurements.triangles) ~= "number" then
        fail(dir, "appraisal.json has no measurements.triangles")
        return
    end
    print(
        ("OK    %-34s %8d tris  relief %-6s  %s"):format(
            dir,
            measurements.triangles,
            tostring(measurements.reliefRatio),
            (decision:gsub("%s+", " "):sub(1, 44))
        )
    )
end

for _, root in ROOTS do
    if not fs.isDir(root) then
        continue
    end
    local names = fs.readDir(root)
    table.sort(names)
    for _, name in names do
        local dir = root .. "/" .. name
        if fs.isDir(dir) and hasBuiltMesh(dir) then
            checkPackage(dir)
        end
    end
end

print("")
print(("%d asset packages checked, %d failed"):format(checked, failures))
if failures > 0 then
    print("An asset without a stated purpose is how the wrong asset gets built on.")
    process.exit(1)
end
