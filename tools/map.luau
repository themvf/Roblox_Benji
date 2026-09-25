-- Map authoring command line. Designers reach it through tools/save_map.sh (Git Bash)
-- or tools/save_map.cmd (plain Windows); both just call this.
--
--     lune run tools/map.luau new <Name>                 blank Convergence draft
--     lune run tools/map.luau duplicate <From> <To>      copy a draft under a new name
--     lune run tools/map.luau convert <Name> [--commit "message"]
--                                                        source -> playable bake + map data
--     lune run tools/map.luau status [<Name>]            is the playable version current?
--     lune run tools/map.luau restore <Name> [<n>]       list / restore earlier sources
--
-- Converting validates the named map only. Other maps' checks stay in CI and in
-- `save_map.sh --all`, so a broken Snow Fortress never blocks a draft, and a draft
-- never weakens them. Converting never stages, commits or pushes unless asked to
-- with --commit, and even then commits only this map's files and never pushes.
--
-- MAPAUTHOR_ROOT points it at another tree (tools/check_map_authoring.luau does this).
-- MAPAUTHOR_FAIL_AFTER=<n> makes installation fail after n files, to prove rollback.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local DateTime = require("@lune/datetime")

-- Map and weapon modules use these as globals.
Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local C = require("./mapauthor/convert")
local Weapons = require("../src/shared/Weapons")

local ROOT = process.env.MAPAUTHOR_ROOT or "."
local HISTORY_KEEP = 30
local RESERVED = { validate = true, lobby = true }

local function say(...)
    print(...)
end

local function fail(msg)
    say("\n" .. msg)
    process.exit(1)
end

local function ensureDir(path)
    if not fs.isDir(path) then
        fs.writeDir(path)
    end
end

local function dirOf(path)
    return path:match("^(.*)/[^/]*$") or "."
end

local function mapNames()
    local out = {}
    local dir = ROOT .. "/src/shared/Maps"
    if fs.isDir(dir) then
        for _, f in fs.readDir(dir) do
            if f:sub(-4) == ".lua" then
                table.insert(out, f:sub(1, -5))
            end
        end
    end
    local src = ROOT .. "/assets/environment/source"
    if fs.isDir(src) then
        for _, f in fs.readDir(src) do
            if f:sub(-5) == ".rbxm" then
                table.insert(out, f:sub(1, -6))
            end
        end
    end
    return out
end

local function checkNewName(name)
    if not name or not name:match("^[A-Z][A-Za-z0-9]+$") or #name > 32 then
        fail(
            ("%q is not a usable map name. Use letters and digits, starting with a capital, e.g. TestMap."):format(
                tostring(name)
            )
        )
    end
    if RESERVED[name:lower()] then
        fail(name .. " is reserved. Pick another name.")
    end
    -- Windows paths and /map lookups are case-insensitive, so TestMap and testmap clash.
    for _, existing in mapNames() do
        if existing:lower() == name:lower() then
            fail(
                ("A map called %s already exists. Pick another name (nothing was changed)."):format(existing)
                    .. ("\nTo copy it instead: bash tools/save_map.sh duplicate %s <NewName>"):format(existing)
            )
        end
    end
    for _, p in { C.paths(ROOT, name).bake } do
        if fs.isFile(p) then
            fail(p .. " already exists. Pick another name (nothing was changed).")
        end
    end
end

-- ===== source history =====
-- Every conversion snapshots the source first, so a bad save can be undone even when
-- git never saw it. Local only (.gitignore); committed versions are in git as well.

local function historyDir(name)
    return ROOT .. "/assets/environment/source/.history/" .. name
end

local function snapshots(name)
    local dir = historyDir(name)
    local out = {}
    if fs.isDir(dir) then
        for _, entry in fs.readDir(dir) do
            local n = tonumber(entry)
            if n and fs.isFile(dir .. "/" .. entry .. "/info.json") then
                local info = serde.decode("json", fs.readFile(dir .. "/" .. entry .. "/info.json"))
                table.insert(out, { n = n, dir = dir .. "/" .. entry, info = info })
            end
        end
    end
    table.sort(out, function(a, b)
        return a.n < b.n
    end)
    return out
end

local function snapshot(name, why)
    local P = C.paths(ROOT, name)
    if not fs.isFile(P.source) then
        return nil
    end
    local presentation = fs.isFile(P.presentation) and fs.readFile(P.presentation) or ""
    local source = fs.readFile(P.source)
    -- the revision a conversion would stamp: a missing presentation file means defaults
    local rev = C.revision(source, presentation ~= "" and presentation or C.PRESENTATION_DEFAULT)
    local list = snapshots(name)
    local last = list[#list]
    if last and last.info.revision == rev then
        return last
    end
    local n = last and last.n + 1 or 1
    local dir = ("%s/%04d"):format(historyDir(name), n)
    ensureDir(dir)
    fs.writeFile(dir .. "/source.rbxm", source)
    if presentation ~= "" then
        fs.writeFile(dir .. "/presentation.lua", presentation)
    end
    fs.writeFile(
        dir .. "/info.json",
        serde.encode("json", { revision = rev, saved = DateTime.now():toIsoDate(), why = why })
    )
    for i = 1, #list + 1 - HISTORY_KEEP do
        fs.removeDir(list[i].dir)
    end
    return { n = n, dir = dir }
end

-- ===== change summary =====

local function oldState(P)
    local state = {}
    if fs.isFile(P.map) then
        state.layout = C.loadLua(fs.readFile(P.map), "previous")
    end
    if fs.isFile(P.bake) then
        state.bakeBytes = fs.readFile(P.bake)
        local ok, roots = pcall(roblox.deserializeModel, state.bakeBytes)
        if ok then
            local n = 0
            for _, r in roots do
                for _, d in r:GetDescendants() do
                    if d:IsA("BasePart") then
                        n += 1
                    end
                end
            end
            state.parts = n
        end
    end
    return state
end

local function dist(a, b)
    return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

local function changes(old, layout, parts, bakeBytes)
    local lines = {}
    local prev = old.layout
    if not prev then
        table.insert(lines, "first playable version of this map")
        return lines
    end
    local before = {}
    for _, o in prev.Objectives or {} do
        before[o.Id] = o
    end
    for _, o in layout.Objectives do
        local b = before[o.Id]
        if not b then
            table.insert(lines, ("objective %s added"):format(o.Id))
        else
            local d = dist(b.pos, o.pos)
            if d > 0.01 then
                table.insert(lines, ("objective %s moved %.1f studs"):format(o.Id, d))
            end
            if math.abs(b.radius - o.radius) > 0.01 or math.abs((b.halfHeight or 0) - o.halfHeight) > 0.01 then
                table.insert(
                    lines,
                    ("objective %s capture area now radius %s, height %s"):format(o.Id, C.num(o.radius), C.num(o.halfHeight))
                )
            end
            if b.Name ~= o.Name then
                table.insert(lines, ("objective %s label now %q"):format(o.Id, o.Name))
            end
            before[o.Id] = nil
        end
    end
    for id in before do
        table.insert(lines, ("objective %s removed"):format(id))
    end
    for _, team in { "Blue", "Red" } do
        local a, b = (prev.Spawns or {})[team] or {}, layout.Spawns[team]
        if #a ~= #b then
            table.insert(lines, ("%s spawns: %d -> %d"):format(team, #a, #b))
        else
            local moved = 0
            for i = 1, #b do
                if dist(a[i], b[i]) > 0.01 then
                    moved += 1
                end
            end
            if moved > 0 then
                table.insert(lines, ("%d %s spawn(s) moved"):format(moved, team))
            end
        end
    end
    if prev.Bounds then
        for _, k in { "min", "max" } do
            if dist(prev.Bounds[k], layout.Bounds[k]) > 0.01 then
                table.insert(lines, "map boundary changed")
                break
            end
        end
    end
    if old.parts and old.parts ~= parts then
        table.insert(lines, ("geometry: %d -> %d parts"):format(old.parts, parts))
    elseif old.bakeBytes and old.bakeBytes ~= bakeBytes then
        table.insert(lines, "geometry edited (same part count)")
    end
    if #lines == 0 then
        table.insert(
            lines,
            prev.Revision == layout.Revision and "no changes since the last conversion"
                or "no gameplay or geometry changes (sky, terrain or labels)"
        )
    end
    return lines
end

-- ===== install =====

-- Write every output as one revision or not at all. Candidates are staged, re-read and
-- validated from the staging copy; only then are targets replaced, each with a backup,
-- and any failure puts every target back as it was.
local function install(name, files)
    local stageRoot = ROOT .. "/.mapbuild/rollback/" .. name
    if fs.isDir(stageRoot) then
        fs.removeDir(stageRoot)
    end
    ensureDir(stageRoot)
    local done = {}
    local failAfter = tonumber(process.env.MAPAUTHOR_FAIL_AFTER or "")
    local ok, why = pcall(function()
        for i, f in files do
            local backup = nil
            if fs.isFile(f.target) then
                backup = stageRoot .. "/" .. i
                fs.writeFile(backup, fs.readFile(f.target))
            end
            table.insert(done, { target = f.target, backup = backup })
            ensureDir(dirOf(f.target))
            fs.writeFile(f.target, f.bytes)
            if failAfter and #done >= failAfter then
                error("simulated failure after " .. #done .. " file(s) (MAPAUTHOR_FAIL_AFTER)")
            end
        end
    end)
    if not ok then
        for i = #done, 1, -1 do
            local d = done[i]
            if d.backup then
                fs.writeFile(d.target, fs.readFile(d.backup))
            elseif fs.isFile(d.target) then
                fs.removeFile(d.target)
            end
        end
    end
    fs.removeDir(stageRoot)
    return ok, why
end

-- ===== commands =====

local function printList(title, list, limit)
    if #list == 0 then
        return
    end
    say(("\n%s (%d):"):format(title, #list))
    for i, line in list do
        if limit and i > limit then
            say(("  ... and %d more"):format(#list - limit))
            break
        end
        say("  - " .. line)
    end
end

local function installedRevision(P)
    if not fs.isFile(P.map) then
        return nil
    end
    local layout = C.loadLua(fs.readFile(P.map), "installed")
    return layout and layout.Revision
end

local function commit(name, message)
    local P = C.paths(ROOT, name)
    local paths = { P.relSource, P.relPresentation, P.relBake, P.relMap }
    local add = process.exec("git", { "add", "--", table.unpack(paths) }, { cwd = ROOT })
    if not add.ok then
        say("git add failed:\n" .. add.stderr)
        return false
    end
    local diff = process.exec("git", { "diff", "--cached", "--quiet", "--", table.unpack(paths) }, { cwd = ROOT })
    if diff.ok then
        say("Nothing to commit for " .. name .. ": these files match the last commit.")
        return true
    end
    -- A pathspec commits exactly these files; anything else already staged stays staged.
    local res = process.exec("git", { "commit", "-m", message, "--", table.unpack(paths) }, { cwd = ROOT })
    if not res.ok then
        say("git commit failed:\n" .. res.stderr .. res.stdout)
        return false
    end
    say((res.stdout:match("^[^\n]*") or "committed") .. "  (not pushed)")
    return true
end

local function convert(name, opts)
    opts = opts or {}
    local P = C.paths(ROOT, name)
    say(("Map: %s"):format(name))
    if fs.isFile(P.source) then
        say("  source:  " .. P.relSource .. "  (saved)")
        snapshot(name, "convert")
    end
    local before = installedRevision(P)
    local old = oldState(P)

    local function notUpdated(errors, warnings)
        printList("Problems -- fix these in Studio, save, and run this again", errors)
        printList("Warnings", warnings or {}, 12)
        say("")
        if before then
            say(("Playable version NOT updated. The game still runs %s, from an earlier save."):format(before))
        else
            say("Playable version NOT created: this map has no playable version yet.")
        end
        say("Your source file is untouched and still saved.")
        process.exit(1)
    end

    local result = C.build(ROOT, name)
    if #result.errors > 0 then
        notUpdated(result.errors, result.warnings)
    end

    -- stage, then validate the staged copies
    local stage = ROOT .. "/.mapbuild/staging/" .. name
    if fs.isDir(stage) then
        fs.removeDir(stage)
    end
    ensureDir(stage)
    fs.writeFile(stage .. "/map.lua", result.luaText)
    fs.writeFile(stage .. "/bake.rbxm", result.bakeBytes)
    local stagedText = fs.readFile(stage .. "/map.lua")
    local stagedBake = roblox.deserializeModel(fs.readFile(stage .. "/bake.rbxm"))
    local errors, warnings, layout, parts = C.validate(name, stagedText, stagedBake, result.authored, Weapons)
    for _, w in result.warnings do
        table.insert(warnings, 1, w)
    end
    if #errors > 0 then
        fs.removeDir(stage)
        notUpdated(errors, warnings)
    end

    local files = {
        { target = P.bake, bytes = fs.readFile(stage .. "/bake.rbxm") },
        { target = P.map, bytes = stagedText },
    }
    if result.presentationIsNew then
        table.insert(files, { target = P.presentation, bytes = result.presentationText })
    end
    local ok, why = install(name, files)
    fs.removeDir(stage)
    if not ok then
        say("\nInstalling the new version failed: " .. tostring(why))
        say("Every output was put back as it was, so bake and data still match each other.")
        notUpdated({}, warnings)
    end

    printList("Warnings (the map still works)", warnings, 12)
    say("\nChanges:")
    for _, line in changes(old, layout, #parts, result.bakeBytes) do
        say("  - " .. line)
    end
    say(("\nPlayable version UPDATED: %s  (%d parts, %d objectives, %d + %d spawns)"):format(
        layout.Revision,
        #parts,
        #layout.Objectives,
        #layout.Spawns.Blue,
        #layout.Spawns.Red
    ))
    if result.presentationIsNew then
        say("  created " .. P.relPresentation .. " with default sky and terrain (optional to edit)")
    end
    if opts.commit then
        commit(name, opts.commit)
    end
    say("\nNext: with `rojo serve` running, Stop and Play again in Studio. Then chat")
    say(("  /explore %s        walk the map"):format(name))
    say(("  /map %s            then step on a Convergence pad to play it (/bots 5 for bots)"):format(name))
    say(("The game prints [MapBuild] %s / %s when it loads this version."):format(name, layout.Revision))
end

local function status(name)
    local names = {}
    if name then
        names = { name }
    else
        local src = ROOT .. "/assets/environment/source"
        if fs.isDir(src) then
            for _, f in fs.readDir(src) do
                if f:sub(-5) == ".rbxm" then
                    table.insert(names, f:sub(1, -6))
                end
            end
        end
        table.sort(names)
        if #names == 0 then
            say("No editable maps yet. Create one: bash tools/save_map.sh new <Name>")
            return true
        end
    end
    local allOk = true
    for _, n in names do
        local P = C.paths(ROOT, n)
        local installed = installedRevision(P)
        if not fs.isFile(P.source) then
            say(("%-16s no editable source (%s)"):format(n, P.relSource))
            allOk = false
        elseif not installed then
            say(("%-16s NO PLAYABLE VERSION YET -- run: bash tools/save_map.sh %s"):format(n, n))
            allOk = false
        else
            local problems = C.freshness(ROOT, n)
            if #problems == 0 then
                say(("%-16s up to date (%s)"):format(n, installed))
            else
                allOk = false
                say(("%-16s STALE -- the game runs %s, which is not your latest save:"):format(n, installed))
                for _, p in problems do
                    say("                   - " .. p)
                end
                say(("                 Run: bash tools/save_map.sh %s"):format(n))
            end
        end
    end
    return allOk
end

local function restore(name, which)
    local list = snapshots(name)
    if #list == 0 then
        fail("No saved history for " .. name .. ". History is recorded each time the map is converted.")
    end
    local P = C.paths(ROOT, name)
    local current = nil
    if fs.isFile(P.source) then
        current = C.revision(
            fs.readFile(P.source),
            fs.isFile(P.presentation) and fs.readFile(P.presentation) or C.PRESENTATION_DEFAULT
        )
    end
    if not which then
        say(("Earlier versions of %s (newest last):"):format(name))
        for _, s in list do
            say(("  %3d  %s  %s%s"):format(
                s.n,
                s.info.saved or "?",
                s.info.revision,
                s.info.revision == current and "  <- current source" or ""
            ))
        end
        say(("\nRestore one with: bash tools/save_map.sh restore %s <number>"):format(name))
        return
    end
    local pick = nil
    for _, s in list do
        if s.n == tonumber(which) then
            pick = s
        end
    end
    if not pick then
        fail(("No version %s. Run without a number to list them."):format(tostring(which)))
    end
    snapshot(name, "before restore")
    fs.writeFile(P.source, fs.readFile(pick.dir .. "/source.rbxm"))
    if fs.isFile(pick.dir .. "/presentation.lua") then
        fs.writeFile(P.presentation, fs.readFile(pick.dir .. "/presentation.lua"))
    end
    say(("Restored %s to version %d (%s). The version you replaced is kept in the history too."):format(
        name,
        pick.n,
        pick.info.revision
    ))
    say("Next: in Studio, delete the old editable copy from Workspace, re-open this one")
    say(("(right-click Workspace > Insert from File > %s), then run: bash tools/save_map.sh %s"):format(P.relSource, name))
end

local function new(name)
    checkNewName(name)
    local P = C.paths(ROOT, name)
    ensureDir(dirOf(P.source))
    fs.writeFile(P.source, C.templateBytes(name))
    say(("Created %s from the blank Convergence template."):format(P.relSource))
    convert(name)
    say(("\nTo edit it: in Studio, right-click Workspace > Insert from File > %s"):format(P.relSource))
end

local function duplicate(from, to)
    local src = C.paths(ROOT, from or "")
    if not from or not fs.isFile(src.source) then
        fail(("No editable map %q to copy (looked for %s)."):format(tostring(from), src.relSource))
    end
    checkNewName(to)
    local roots = roblox.deserializeModel(fs.readFile(src.source))
    local root = nil
    for _, r in roots do
        if r:GetAttribute("MapSource") == from then
            root = r
        end
    end
    if not root or #roots ~= 1 then
        fail(("%s is not a clean editable map; convert it first to see what is wrong."):format(src.relSource))
    end
    root:SetAttribute("MapSource", to)
    root.Name = to .. " — EDITABLE"
    local dst = C.paths(ROOT, to)
    fs.writeFile(dst.source, roblox.serializeModel({ root }))
    if fs.isFile(src.presentation) then
        fs.writeFile(dst.presentation, fs.readFile(src.presentation))
    end
    say(("Copied %s to %s (from the last SAVED version of %s)."):format(from, to, from))
    convert(to)
    say(("\nTo edit it: in Studio, right-click Workspace > Insert from File > %s"):format(dst.relSource))
end

-- ===== argument parsing =====

local args = table.clone(process.args)
local commitMessage = nil
for i = #args, 1, -1 do
    if args[i] == "--commit" or args[i] == "-c" then
        commitMessage = args[i + 1] or ("Update map " .. tostring(args[1]))
        table.remove(args, i + 1)
        table.remove(args, i)
    end
end
local cmd = args[1]

if cmd == "new" then
    new(args[2])
elseif cmd == "duplicate" or cmd == "copy" then
    duplicate(args[2], args[3])
elseif cmd == "convert" then
    if not args[2] then
        fail("Which map? e.g. bash tools/save_map.sh TestMap")
    end
    convert(args[2], { commit = commitMessage })
elseif cmd == "status" then
    if not status(args[2]) then
        process.exit(1)
    end
elseif cmd == "restore" then
    if not args[2] then
        fail("Which map? e.g. bash tools/save_map.sh restore TestMap")
    end
    restore(args[2], args[3])
else
    say([[Map authoring:
  bash tools/save_map.sh new <Name>              start a blank Convergence draft
  bash tools/save_map.sh <Name>                  convert the saved source into the playable map
  bash tools/save_map.sh <Name> --commit "msg"   ...and commit just this map's files (no push)
  bash tools/save_map.sh duplicate <From> <To>   copy a draft under a new name
  bash tools/save_map.sh status [<Name>]         is the playable version your latest save?
  bash tools/save_map.sh restore <Name> [<n>]    list or restore earlier saved sources
  bash tools/save_map.sh --all                   every project gate (what CI runs)]])
    if cmd and cmd ~= "help" then
        process.exit(1)
    end
end
