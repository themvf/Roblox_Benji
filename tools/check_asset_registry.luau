--!strict
-- Every asset the pipeline ships is listed in src/shared/AssetRegistry.json. This gate
-- holds each entry to the rules that were learned the slow way on the wave runner:
--
--   * the export on disk is the file the registry describes (hash)
--   * the uploaded asset is that same file, not an older build (stale upload)
--   * total triangles fit the role's budget, and no mesh is over Roblox's 10,000
--   * the package records where the model came from (provenance.json)
--   * a model template Rojo syncs carries the settings Studio cannot be trusted to
--     default: RenderFidelity Precise (Automatic shreds a generated mesh), no collision
--     on the visual mesh, DoubleSided on an open scan
--   * no asset id from the registry is typed into game code; code reads the registry
--
-- What only eyes in Studio can confirm (does it load, face forward, sit at the right
-- height) is listed per entry under `studio` and printed here as TODO, not failed.
--
-- Entries are written by tools/asset_generate.py (build, publish, register, verify).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local REGISTRY = "src/shared/AssetRegistry.json"
local MESH_CAP = 10000
-- Keep in step with ROLE_BUDGETS in tools/asset_rules.py.
local ROLE_BUDGETS: { [string]: number } = {
    held = 8000,
    interactive = 15000,
    cover = 10000,
    decor = 30000,
    scenery = 60000,
}

-- Named points game code needs before it can use the model. Keep in step with KINDS in
-- tools/asset_rules.py.
local KIND_MOUNTS: { [string]: { string } } = {
    prop = {},
    vehicle = { "DriverSeat", "HullCentre" },
    weapon = { "Grip", "Muzzle" },
}
-- Where a kind's gameName has to appear for the asset to be reachable in a match.
local KIND_WIRING: { [string]: { { path: string, what: string } } } = {
    vehicle = {
        { path = "src/server/Services/VehicleService.lua", what = "a VEHICLE_SPECS entry and a builder" },
    },
    weapon = {
        { path = "src/shared/Weapons/init.lua", what = "its stats" },
        { path = "tools/build_weapons.luau", what = "a kit base in BASE and its art attached" },
    },
}

local failures = 0
local todos = 0

local function fail(key: string, message: string)
    failures += 1
    print(("FAIL  %-28s %s"):format(key, message))
end

-- Triangle count of each mesh in a GLB, read from its JSON chunk alone.
local function glbTriangles(path: string): ({ number }?, string?)
    local data = fs.readFile(path)
    if data:sub(1, 4) ~= "glTF" then
        return nil, "not a binary glTF file"
    end
    local length = string.unpack("<I4", data, 13)
    local ok, doc = pcall(serde.decode, "json" :: any, data:sub(21, 20 + length))
    if not ok or type(doc) ~= "table" then
        return nil, "unreadable glTF JSON"
    end
    local counts = {}
    for _, mesh in doc.meshes or {} do
        local total = 0
        for _, prim in mesh.primitives or {} do
            if (prim.mode or 4) == 4 then
                local accessor = prim.indices or prim.attributes.POSITION
                total += doc.accessors[accessor + 1].count // 3
            end
        end
        table.insert(counts, total)
    end
    return counts, nil
end

-- Lune cannot decode every enum property of every file version; a property it cannot
-- read is skipped rather than guessed at.
local function read(inst: any, property: string): any
    local ok, value = pcall(function()
        return inst[property]
    end)
    return if ok then value else nil
end

local function checkTemplate(key: string, entry: any)
    local path = entry.template
    if not fs.isFile(path) then
        fail(key, "template " .. path .. " does not exist")
        return
    end
    local meshParts = 0
    local function visit(inst: any)
        if inst.ClassName == "MeshPart" then
            meshParts += 1
            local where = path .. " " .. inst.Name
            local render, collision = read(inst, "RenderFidelity"), read(inst, "CollisionFidelity")
            if render ~= roblox.Enum.RenderFidelity.Precise then
                fail(key, where .. ": RenderFidelity must be Precise; Automatic swaps in a shredded low-detail mesh")
            end
            if inst.CanCollide then
                fail(key, where .. ": the visual mesh must not collide; give the asset simple invisible blocks")
            end
            if collision ~= nil and collision ~= roblox.Enum.CollisionFidelity.Box then
                fail(key, where .. ": CollisionFidelity must be Box so no hull is computed for a mesh that never collides")
            end
            if entry.route == "scan" and not read(inst, "DoubleSided") then
                fail(key, where .. ": a scan is open shells; DoubleSided must be on or the game shows through it")
            end
        end
        for _, child in inst:GetChildren() do
            visit(child)
        end
    end
    for _, root in roblox.deserializeModel(fs.readFile(path)) do
        visit(root)
    end
    if meshParts == 0 then
        fail(key, "template " .. path .. " holds no MeshPart")
    end
end

local function checkEntry(key: string, entry: any)
    local before = failures
    if type(entry.package) ~= "string" or not fs.isDir(entry.package) then
        fail(key, "package directory is missing: " .. tostring(entry.package))
        return
    end
    local budget = ROLE_BUDGETS[entry.role]
    if not budget then
        fail(key, "unknown role " .. tostring(entry.role))
        return
    end
    if not fs.isFile(entry.package .. "/brief.json") then
        fail(key, "no brief.json: the role, size and route were never written down")
    end
    if not fs.isFile(entry.package .. "/provenance.json") then
        fail(key, "no provenance.json -- run: python tools/asset_generate.py provenance <name>")
    end

    local triangles = entry.triangles
    if type(entry.export) == "string" then
        if not fs.isFile(entry.export) then
            fail(key, "export is missing: " .. entry.export)
        else
            if serde.hash("sha256" :: any, fs.readFile(entry.export)) ~= entry.exportSha256 then
                fail(key, "export changed since it was recorded -- run asset_generate.py build so it is checked again")
            end
            local counts, problem = glbTriangles(entry.export)
            if not counts then
                fail(key, entry.export .. ": " .. tostring(problem))
            else
                triangles = 0
                for _, count in counts do
                    triangles += count
                    if count > MESH_CAP then
                        fail(key, ("a mesh has %d triangles; Roblox rejects over %d"):format(count, MESH_CAP))
                    end
                end
            end
        end
        if entry.assetId ~= nil and entry.uploadedSha256 ~= entry.exportSha256 then
            fail(key, ("asset %s is an older build than the export on disk -- publish again or restore the export"):format(tostring(entry.assetId)))
        end
    end
    if type(triangles) ~= "number" then
        fail(key, "no triangle count recorded")
    elseif triangles > budget then
        local waiver = entry.budgetWaiver
        if type(waiver) ~= "string" or waiver:gsub("%s", "") == "" then
            fail(key, ("%d triangles is over the %d allowed for role %s, with no budgetWaiver"):format(triangles, budget, entry.role))
        end
    end
    if type(entry.template) == "string" then
        checkTemplate(key, entry)
    end

    local open = {}
    local kind = entry.kind or "prop"
    local needed = KIND_MOUNTS[kind]
    if not needed then
        fail(key, "unknown kind " .. tostring(kind))
    else
        for _, name in needed do
            local point = entry.mounts and entry.mounts[name]
            if type(point) ~= "table" or #point ~= 3 then
                fail(key, ("kind %s has no %s mount -- asset_generate.py brief <name> --mount %s=x,y,z, then build"):format(kind, name, name))
            end
        end
        -- Wiring is game code a person writes, so before upload it is a reminder and
        -- after upload, when the id can reach a match, it is a failure.
        for _, wire in KIND_WIRING[kind] or {} do
            local name = entry.gameName
            local wired = type(name) == "string" and fs.isFile(wire.path) and fs.readFile(wire.path):find(name, 1, true) ~= nil
            if not wired then
                local message = ("%s needs %s in %s"):format(tostring(name or "(no gameName)"), wire.what, wire.path)
                if entry.assetId ~= nil and type(entry.export) == "string" then
                    fail(key, message)
                else
                    table.insert(open, "wiring: " .. message)
                end
            end
        end
    end
    if entry.assetId ~= nil or entry.template ~= nil then
        for name, done in (entry.studio and entry.studio.checks) or {} do
            if not done then
                table.insert(open, "Studio check: " .. name)
            end
        end
        table.sort(open)
    end
    if failures == before then
        local id = if entry.assetId ~= nil then ("asset %.0f"):format(entry.assetId) else "not uploaded"
        print(("OK    %-28s %6d tris  %-11s %-5s  %s"):format(key, triangles or 0, entry.role, entry.route, id))
    end
    if #open > 0 then
        todos += 1
        print(("TODO  %-28s still open: %s"):format(key, table.concat(open, ", ")))
    end
end

if not fs.isFile(REGISTRY) then
    print("no " .. REGISTRY .. "; nothing to check")
    return
end
local registry = serde.decode("json", fs.readFile(REGISTRY))
local keys = {}
for key in registry do
    table.insert(keys, key)
end
table.sort(keys)
for _, key in keys do
    checkEntry(key, registry[key])
end

-- An id typed into a script goes stale silently when the asset is rebuilt and uploaded
-- again. Code reads require(ReplicatedStorage.Shared.AssetRegistry)[name].assetId instead.
local ids: { [string]: string } = {}
for _, key in keys do
    if registry[key].assetId ~= nil then
        ids[("%.0f"):format(registry[key].assetId)] = key
    end
end
local function scan(dir: string)
    for _, name in fs.readDir(dir) do
        local path = dir .. "/" .. name
        if fs.isDir(path) then
            scan(path)
        elseif name:sub(-4) == ".lua" or name:sub(-5) == ".luau" then
            local text = fs.readFile(path)
            for id, key in ids do
                if text:find(id, 1, true) then
                    fail(key, ("asset id %s is typed into %s; read it from Shared.AssetRegistry"):format(id, path))
                end
            end
        end
    end
end
scan("src")

print("")
print(("%d registered assets checked, %d failed, %d with Studio checks outstanding"):format(#keys, failures, todos))
if failures > 0 then
    process.exit(1)
end
