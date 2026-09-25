-- Build gate: the map authoring loop, end to end, in a throwaway tree.
--
-- Drives tools/map.luau exactly as a designer's commands would, and edits the saved
-- source the way Studio would (moving markers, adding a kit piece, deleting things),
-- then checks what comes out. Each block names the acceptance criterion it covers in
-- docs/design/map-authoring/design-packet.md. What it cannot cover -- Studio's own
-- tools, and playing the result -- is listed there as manual evidence.
--
--     lune run tools/check_map_authoring.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local C = require("./mapauthor/convert")
local FinalePlan = require("../src/server/FinalePlan")

local ROOT = ".mapbuild/test"
local passed, failed = 0, 0

local function reset()
    if fs.isDir(ROOT) then
        fs.removeDir(ROOT)
    end
    fs.writeDir(ROOT)
end

local function run(args, env)
    env = env or {}
    env.MAPAUTHOR_ROOT = ROOT
    local r = process.exec("lune", { "run", "tools/map.luau", table.unpack(args) }, { env = env })
    return r.ok, r.stdout .. r.stderr
end

local function check(id, what, cond, detail)
    if cond then
        passed += 1
        print(("PASS  %-4s %s"):format(id, what))
    else
        failed += 1
        print(("FAIL  %-4s %s"):format(id, what))
        if detail then
            print("        " .. tostring(detail):gsub("\n", "\n        "))
        end
    end
end

local function P(name)
    return C.paths(ROOT, name)
end

local function read(path)
    return fs.isFile(path) and fs.readFile(path) or nil
end

local function layoutOf(name)
    return C.loadLua(fs.readFile(P(name).map), name)
end

local function outputs(name)
    return { map = read(P(name).map), bake = read(P(name).bake) }
end

-- Edit the saved source the way Studio would, and save it back.
local function edit(name, fn)
    local path = P(name).source
    local roots = roblox.deserializeModel(fs.readFile(path))
    fn(roots[1])
    fs.writeFile(path, roblox.serializeModel(roots))
end

local function find(root, path)
    local inst = root
    for part in path:gmatch("[^/]+") do
        inst = inst and inst:FindFirstChild(part)
    end
    return assert(inst, "no " .. path)
end

local function near(a, b)
    return math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end

local function moveBy(inst, offset)
    for _, d in { inst, table.unpack(inst:GetDescendants()) } do
        if d:IsA("BasePart") then
            d.CFrame = d.CFrame + offset
        end
    end
end

reset()

-- ===== A01 / A12: a blank draft, with every setting created =====
local ok, out = run({ "new", "TestMap" })
check("A01", "new draft converts with no hand-written files", ok, out)
local L = layoutOf("TestMap")
check(
    "A01",
    "draft has 3 objectives, both spawn teams, bounds, finale",
    #L.Objectives == 3
        and #L.Spawns.Blue == 6
        and #L.Spawns.Red == 6
        and L.Bounds ~= nil
        and #L.Finale.EligibleIds == 3
        and L.Draft == true
        and L.RequiresBake == true
)
check("A01", "presentation defaults file created", fs.isFile(P("TestMap").presentation))
check("A12", "a 1-part starter passes (no part-count floor)", ok and out:find("1 parts") ~= nil, out)

-- ===== A02: grounded objectives; previews match generated capture dimensions =====
local grounded = true
for _, o in L.Objectives do
    grounded = grounded and o.pos[2] == 0
end
check("A02", "all starter objectives sit on the ground (y = 0)", grounded)
do
    local root = roblox.deserializeModel(fs.readFile(P("TestMap").source))[1]
    local match = true
    for _, o in L.Objectives do
        local cap = find(root, "Authoring/Objectives/" .. o.Id .. "/Capture")
        match = match
            and math.abs(cap.Size.X - o.halfHeight) < 1e-3
            and math.abs(cap.Size.Y / 2 - o.radius) < 1e-3
            and math.abs((cap.CFrame.Position.Y - cap.Size.X / 2) - o.pos[2]) < 1e-3
    end
    check("A02", "capture cylinders match generated radius, height and floor point", match)
    local labels = {}
    for _, d in root:GetDescendants() do
        if d:IsA("TextLabel") then
            labels[d.Text] = true
        end
    end
    check(
        "A02",
        "viewport labels name A, B, C, both teams and the boundary",
        labels["OBJECTIVE A"]
            and labels["OBJECTIVE B"]
            and labels["OBJECTIVE C"]
            and labels["BLUE SPAWN"]
            and labels["RED SPAWN"]
            and labels["MAP BOUNDARY"]
    )
    local inert = true
    for _, d in find(root, "Authoring"):GetDescendants() do
        if d:IsA("BasePart") and (d.CanCollide or d.CanTouch or d.CanQuery) then
            inert = false
        end
    end
    check("A02", "no authoring helper collides, touches or takes raycasts", inert)
end

-- ===== A03 / A04: move a marker, convert, gameplay data follows; again =====
edit("TestMap", function(root)
    moveBy(find(root, "Authoring/Objectives/A"), Vector3.new(40, 0, 20))
    moveBy(find(root, "Authoring/Spawns/Blue/Spawn 1"), Vector3.new(0, 0, -10))
end)
ok, out = run({ "convert", "TestMap" })
L = layoutOf("TestMap")
check("A03", "moved objective A and a spawn: conversion succeeds", ok, out)
check("A03", "generated objective A is at the authored position", near(L.Objectives[1].pos, { 40, 0, -108 }))
check("A03", "generated Blue spawn 1 is at the authored position", near(L.Spawns.Blue[1], { -210, 0, -30 }))
check("A03", "summary reports the move", out:find("objective A moved") ~= nil, out)
edit("TestMap", function(root)
    check("A04", "source still carries its markers after conversion", #find(root, "Authoring/Objectives"):GetChildren() == 3)
    moveBy(find(root, "Authoring/Objectives/A"), Vector3.new(-40, 0, 0))
end)
ok, out = run({ "convert", "TestMap" })
check("A04", "second edit converts without rebuilding markers", ok and near(layoutOf("TestMap").Objectives[1].pos, { 0, 0, -108 }), out)

-- ===== A05: a prepared kit piece in Geometry =====
edit("TestMap", function(root)
    local piece = roblox.deserializeModel(fs.readFile("assets/environment/kit/SniperOutpost.rbxm"))[1]
    moveBy(piece, Vector3.new(120, 0, 110))
    piece.Parent = find(root, "Geometry")
end)
ok, out = run({ "convert", "TestMap" })
check("A05", "kit piece placed in Geometry converts with no data edits", ok, out)
do
    local bake = roblox.deserializeModel(fs.readFile(P("TestMap").bake))[1]
    local parts = 0
    for _, d in bake:GetDescendants() do
        if d:IsA("BasePart") then
            parts += 1
        end
    end
    check("A05", "the piece is in the playable bake", parts > 1 and bake:FindFirstChild("Geometry"):FindFirstChild("SniperOutpost") ~= nil)
end

-- free models bring scripts along; none may reach the bake
edit("TestMap", function(root)
    local script = roblox.Instance.new("Script")
    script.Name = "Spreader"
    script.Parent = find(root, "Geometry/SniperOutpost")
end)
ok, out = run({ "convert", "TestMap" })
check("A05", "a script inside a map piece is refused and named", not ok and out:find("Spreader") ~= nil, out)
edit("TestMap", function(root)
    find(root, "Geometry/SniperOutpost/Spreader").Parent = nil
end)
ok, out = run({ "convert", "TestMap" })
check("A05", "without the script it converts again", ok, out)

-- ===== A13: no helpers in the bake; conversion repeatable =====
do
    local bake = roblox.deserializeModel(fs.readFile(P("TestMap").bake))[1]
    local leaks = {}
    for _, d in bake:GetDescendants() do
        if d:GetAttribute("AuthoringHelper") ~= nil or d:GetAttribute("Role") ~= nil or d.Name == "Authoring" then
            table.insert(leaks, d:GetFullName())
        end
    end
    check("A13", "playable bake contains no authoring helpers", #leaks == 0, table.concat(leaks, ", "))
end

-- ===== A10: deterministic; freshness catches hand edits =====
local before = outputs("TestMap")
ok, out = run({ "convert", "TestMap" })
local after = outputs("TestMap")
check("A10", "unchanged source converts to byte-identical outputs", ok and before.map == after.map and before.bake == after.bake, out)
ok, out = run({ "status", "TestMap" })
check("A10", "status reports up to date", ok and out:find("up to date") ~= nil, out)
fs.writeFile(P("TestMap").map, (after.map:gsub("radius = 18", "radius = 25", 1)))
ok, out = run({ "status", "TestMap" })
check("A10", "hand-edited map data is caught", not ok and out:find("STALE") ~= nil, out)
fs.writeFile(P("TestMap").map, after.map)
fs.writeFile(P("TestMap").bake, after.bake .. "x")
ok, out = run({ "status", "TestMap" })
check("A10", "hand-edited bake is caught", not ok and out:find("baked") ~= nil, out)
fs.writeFile(P("TestMap").bake, after.bake)
edit("TestMap", function(root)
    moveBy(find(root, "Authoring/Objectives/B"), Vector3.new(0, 0, -8))
end)
ok, out = run({ "status", "TestMap" })
check("A10", "a saved-but-unconverted edit reads as stale", not ok and out:find("STALE") ~= nil, out)
run({ "convert", "TestMap" })

-- ===== A08: a broken edit is refused and keeps the previous playable version =====
before = outputs("TestMap")
edit("TestMap", function(root)
    find(root, "Authoring/Objectives/C").Parent = nil
end)
ok, out = run({ "convert", "TestMap" })
check("A08", "removing an objective is a named, blocking problem", not ok and out:find("exactly 3 objectives") ~= nil, out)
check("A08", "output says the playable version was NOT updated", out:find("NOT updated") ~= nil, out)
after = outputs("TestMap")
check("A08", "previous playable outputs are untouched", before.map == after.map and before.bake == after.bake)
local goodVersionOut = out
ok, out = run({ "restore", "TestMap" })
check("A17", "history lists earlier sources", ok and out:find("Earlier versions") ~= nil, out)
-- the snapshot before the broken one is the last good source
local lastGood = nil
for n in out:gmatch("\n%s+(%d+)%s") do
    lastGood = tonumber(n)
end
lastGood = lastGood and lastGood - 1
ok, out = run({ "restore", "TestMap", tostring(lastGood) })
check("A17", "restore brings back the earlier source", ok, out)
ok, out = run({ "convert", "TestMap" })
check("A17", "restored source (with its guides) converts again", ok and #layoutOf("TestMap").Objectives == 3, out .. goodVersionOut)

edit("TestMap", function(root)
    find(root, "Authoring/Objectives/B"):SetAttribute("ObjectiveId", "A")
end)
ok, out = run({ "convert", "TestMap" })
check("A08", "duplicate objective ID is a named, blocking problem", not ok and out:find("share ObjectiveId") ~= nil, out)
edit("TestMap", function(root)
    find(root, "Authoring/Objectives/B"):SetAttribute("ObjectiveId", "B")
end)

-- placement problems name the object and the fix
edit("TestMap", function(root)
    moveBy(find(root, "Authoring/Spawns/Red/Spawn 3"), Vector3.new(60, 0, 0))
end)
ok, out = run({ "convert", "TestMap" })
check("A08", "spawn outside the boundary is named with a fix", not ok and out:find('Red spawn "Spawn 3"') ~= nil and out:find("outside the Map Boundary") ~= nil, out)
edit("TestMap", function(root)
    moveBy(find(root, "Authoring/Spawns/Red/Spawn 3"), Vector3.new(-60, 12, 0))
end)
ok, out = run({ "convert", "TestMap" })
check("A08", "floating spawn is named", not ok and out:find("floats") ~= nil, out)
edit("TestMap", function(root)
    moveBy(find(root, "Authoring/Spawns/Red/Spawn 3"), Vector3.new(0, -12, 0))
end)
ok, out = run({ "convert", "TestMap" })
check("A08", "fixed map converts again", ok, out)

-- ===== A09: failure part-way through installing =====
edit("TestMap", function(root)
    moveBy(find(root, "Authoring/Objectives/B"), Vector3.new(0, 0, 10))
end)
before = outputs("TestMap")
ok, out = run({ "convert", "TestMap" }, { MAPAUTHOR_FAIL_AFTER = "1" })
after = outputs("TestMap")
check("A09", "injected install failure reports failure", not ok and out:find("simulated failure") ~= nil, out)
check("A09", "no mixed revision: both outputs rolled back", before.map == after.map and before.bake == after.bake)
ok, out = run({ "convert", "TestMap" })
check("A09", "next conversion succeeds", ok, out)

-- ===== A07: whole-map transforms and boundary edits =====
before = outputs("TestMap")
local L0 = layoutOf("TestMap")
local function allMarkers(L, fn)
    local ok = true
    for i, o in L.Objectives do
        ok = ok and fn(o.pos, L0.Objectives[i].pos) and math.abs(o.radius - L0.Objectives[i].radius) < 0.01
    end
    for _, team in { "Blue", "Red" } do
        for i, s in L.Spawns[team] do
            ok = ok and fn(s, L0.Spawns[team][i])
        end
    end
    return ok and fn(L.Bounds.min, L0.Bounds.min) and fn(L.Bounds.max, L0.Bounds.max)
end
-- What Studio does on Insert from File: re-centres the model's pivot on its bounding box.
-- This once sank a real map 36.5 studs under the terrain; the pivot must not matter.
edit("TestMap", function(root)
    root.WorldPivotData = CFrame.new(0, 36.5, 0)
end)
ok, out = run({ "convert", "TestMap" })
L = layoutOf("TestMap")
check("A07", "Studio re-centring the model's pivot changes nothing", ok and allMarkers(L, near), out)
check("A07", "... including the geometry", read(P("TestMap").bake) == before.bake)
edit("TestMap", function(root)
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") then
            d.CFrame = d.CFrame + Vector3.new(80, 0, 0)
        end
    end
end)
ok, out = run({ "convert", "TestMap" })
L = layoutOf("TestMap")
check(
    "A07",
    "moving the whole map moves every anchor by the same amount",
    ok and allMarkers(L, function(a, b)
        return near(a, { b[1] + 80, b[2], b[3] })
    end),
    out
)
edit("TestMap", function(root)
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") then
            d.CFrame = d.CFrame + Vector3.new(-80, -20, 0)
        end
    end
end)
ok, out = run({ "convert", "TestMap" })
check("A07", "a map sunk under the terrain is refused", not ok and out:find("under the terrain") ~= nil, out)
edit("TestMap", function(root)
    local turn = CFrame.new(0, 20, 0) * CFrame.Angles(0, math.rad(30), 0)
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") then
            d.CFrame = turn * d.CFrame
        end
    end
end)
ok, out = run({ "convert", "TestMap" })
check("A07", "turning the whole map is refused with a fix", not ok and out:find("Map Boundary is rotated") ~= nil, out)
edit("TestMap", function(root)
    local back = CFrame.Angles(0, math.rad(-30), 0) * CFrame.new(0, -20, 0)
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") then
            d.CFrame = CFrame.new(0, 20, 0) * back * d.CFrame
        end
    end
end)
ok, out = run({ "convert", "TestMap" })
check("A07", "turned back, it converts to the original positions", ok and allMarkers(layoutOf("TestMap"), near), out)
edit("TestMap", function(root)
    local b = find(root, "Authoring/Bounds")
    b.Size = b.Size + Vector3.new(20, 0, 0)
end)
ok, out = run({ "convert", "TestMap" })
L = layoutOf("TestMap")
check("A07", "enlarged boundary is generated", ok and math.abs((L.Bounds.max[1] - L.Bounds.min[1]) - 510) < 0.01, out)
check("A07", "boundary past the ground is a warning, not a silent change", out:find("stops more than 6 studs short") ~= nil, out)
edit("TestMap", function(root)
    local b = find(root, "Authoring/Bounds")
    b.CFrame = b.CFrame * CFrame.Angles(0, math.rad(45), 0)
end)
ok, out = run({ "convert", "TestMap" })
check("A07", "rotated boundary is refused with a fix", not ok and out:find("Map Boundary is rotated") ~= nil, out)
edit("TestMap", function(root)
    local b = find(root, "Authoring/Bounds")
    b.CFrame = b.CFrame * CFrame.Angles(0, math.rad(-45), 0)
    local cap = find(root, "Authoring/Objectives/C/Capture")
    cap.CFrame = cap.CFrame * CFrame.Angles(0, 0, math.rad(20))
end)
ok, out = run({ "convert", "TestMap" })
check("A07", "tilted capture area is refused with a fix", not ok and out:find("is tilted") ~= nil, out)
edit("TestMap", function(root)
    local cap = find(root, "Authoring/Objectives/C/Capture")
    cap.CFrame = cap.CFrame * CFrame.Angles(0, 0, math.rad(-20))
end)
ok, out = run({ "convert", "TestMap" })
check("A07", "restored map converts", ok, out)

-- ===== presentation overrides survive; spatial keys are refused there =====
do
    local path = P("TestMap").presentation
    local text = fs.readFile(path)
    fs.writeFile(path, (text:gsub("ClockTime = 12", "ClockTime = 18")))
    ok, out = run({ "convert", "TestMap" })
    check("PRES", "presentation edit reaches the map", ok and layoutOf("TestMap").Environment.ClockTime == 18, out)
    ok, out = run({ "convert", "TestMap" })
    check("PRES", "presentation edit survives the next conversion", ok and layoutOf("TestMap").Environment.ClockTime == 18)
    fs.writeFile(path, (fs.readFile(path):gsub("return {", "return {\n    Objectives = {},", 1)))
    ok, out = run({ "convert", "TestMap" })
    check("PRES", "spatial settings in presentation are refused", not ok and out:find("not a presentation setting") ~= nil, out)
    fs.writeFile(path, (fs.readFile(path):gsub("\n    Objectives = {},", "", 1)))
end

-- ===== A06: duplicate is independent =====
ok, out = run({ "convert", "TestMap" })
before = outputs("TestMap")
local srcBefore = read(P("TestMap").source)
ok, out = run({ "duplicate", "TestMap", "SecondMap" })
check("A06", "duplicate creates a second converted draft", ok and fs.isFile(P("SecondMap").map), out)
edit("SecondMap", function(root)
    check("A06", "copy is labelled as the new map", root:GetAttribute("MapSource") == "SecondMap")
    moveBy(find(root, "Authoring/Objectives/C"), Vector3.new(0, 0, 30))
end)
ok, out = run({ "convert", "SecondMap" })
after = outputs("TestMap")
check("A06", "editing the copy leaves the original untouched", ok and before.map == after.map and before.bake == after.bake and read(P("TestMap").source) == srcBefore, out)
ok, out = run({ "duplicate", "TestMap", "TESTMAP" })
check("A06", "a name that clashes (any case) is refused", not ok and out:find("already exists") ~= nil, out)
ok, out = run({ "new", "SecondMap" })
check("A06", "new never overwrites an existing map", not ok and out:find("already exists") ~= nil, out)
-- saving one map's model over another's file is caught
fs.writeFile(P("SecondMap").source, fs.readFile(P("TestMap").source))
ok, out = run({ "convert", "SecondMap" })
check("A06", "saving the wrong map over a file is caught", not ok and out:find("not \"SecondMap\"") ~= nil, out)
run({ "restore", "SecondMap", "1" })

-- ===== A11: a broken unrelated map does not block the draft =====
fs.writeFile(ROOT .. "/src/shared/Maps/Broken.lua", "return { this is not lua")
ok, out = run({ "convert", "TestMap" })
check("A11", "draft converts while an unrelated map is broken", ok, out)
fs.removeFile(ROOT .. "/src/shared/Maps/Broken.lua")

-- ===== A15: every eligible objective can be the finale =====
do
    L = layoutOf("TestMap")
    local finals = {}
    for pick = 1, 3 do
        local plan = FinalePlan.create("authoring-check-" .. pick, L.Objectives, L.Finale, function(n)
            return math.min(pick, n)
        end)
        if plan then
            finals[plan.FinalId] = true
            local live = { 0, 0, 0 }
            for phase = 1, 3 do
                for _, o in L.Objectives do
                    if FinalePlan.live(plan, o.Id, phase) then
                        live[phase] += 1
                    end
                end
            end
            check("A15", "finale " .. plan.FinalId .. ": 3 -> 2 -> 1 live objectives", live[1] == 3 and live[2] == 2 and live[3] == 1)
        end
    end
    check("A15", "all three objectives can be chosen as the finale", finals.A and finals.B and finals.C)
    edit("TestMap", function(root)
        find(root, "Authoring/Objectives/A"):SetAttribute("FinaleEligible", nil)
    end)
    ok, out = run({ "convert", "TestMap" })
    check("A15", "missing finale setting is an error, not a silent downgrade", not ok and out:find("FinaleEligible") ~= nil, out)
    edit("TestMap", function(root)
        find(root, "Authoring/Objectives/A"):SetAttribute("FinaleEligible", true)
    end)
end

-- ===== A16: conversion never commits; --commit takes only this map's files =====
do
    local function git(args)
        local r = process.exec("git", args, { cwd = ROOT })
        return r.ok, r.stdout .. r.stderr
    end
    git({ "init", "-q" })
    git({ "config", "user.email", "check@example.invalid" })
    git({ "config", "user.name", "check" })
    git({ "commit", "-q", "--allow-empty", "-m", "base" })
    ok, out = run({ "convert", "TestMap" })
    local _, log = git({ "rev-list", "--count", "HEAD" })
    check("A16", "default conversion makes no commit", ok and log:match("^%s*1") ~= nil, log)
    fs.writeFile(ROOT .. "/unrelated.txt", "someone else's work")
    git({ "add", "unrelated.txt" })
    edit("TestMap", function(root)
        moveBy(find(root, "Authoring/Objectives/B"), Vector3.new(0, 0, 4))
    end)
    ok, out = run({ "convert", "TestMap", "--commit", "Move B" })
    local _, files = git({ "show", "--name-only", "--format=", "HEAD" })
    local _, staged = git({ "diff", "--cached", "--name-only" })
    check(
        "A16",
        "--commit commits source, presentation, bake and data together",
        ok
            and files:find("assets/environment/source/TestMap.rbxm", 1, true) ~= nil
            and files:find("assets/environment/source/TestMap.presentation.lua", 1, true) ~= nil
            and files:find("assets/environment/baked/TestMap.rbxm", 1, true) ~= nil
            and files:find("src/shared/Maps/TestMap.lua", 1, true) ~= nil,
        out .. files
    )
    check("A16", "--commit leaves unrelated staged work staged and uncommitted", files:find("unrelated") == nil and staged:find("unrelated.txt", 1, true) ~= nil, files .. staged)
    check("A16", "--commit does not push", out:find("not pushed") ~= nil, out)
end

if failed == 0 then
    fs.removeDir(ROOT)
end
print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    print("(left " .. ROOT .. " in place for inspection)")
    process.exit(1)
end
