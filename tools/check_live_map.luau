-- Build gate: pressing Play in Studio with a map in Workspace plays that map.
--
-- Runs the real MapService source against a stand-in Workspace: the template map, a
-- piece correctly inside its Geometry, and pieces left loose beside it. Checks that the
-- map is read live (with Shared.MapAuthoring, the converter's own reader), becomes the
-- startup map, beats a saved module of the same name, and that loose pieces are left
-- out and named. Building the world itself is not simulated here; Studio does that.
--
--     lune run tools/check_live_map.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local Template = require("./mapauthor/template")
local Validate = require("../src/shared/Maps/Validate")
local MapAuthoring = require("../src/shared/MapAuthoring")

local passed, failed = 0, 0
local function check(what, cond, detail)
    if cond then
        passed += 1
        print("PASS  " .. what)
    else
        failed += 1
        print("FAIL  " .. what)
        if detail then
            print("        " .. tostring(detail))
        end
    end
end

local function run(opts)
    local workspace = roblox.Instance.new("Folder")
    workspace.Name = "Workspace"
    local source = Template.build("LiveMap")
    local kit = roblox.deserializeModel(fs.readFile("assets/environment/kit/Helipad.rbxm"))[1]
    kit.Parent = source:FindFirstChild("Geometry")
    source.Parent = workspace
    for _, name in { "Fortress", "Pallet" } do
        local loose = roblox.Instance.new("Model")
        loose.Name = name
        loose.Parent = workspace
    end
    local camera = roblox.Instance.new("Camera")
    camera.Parent = workspace
    if opts.breakIt then
        source.Authoring.Objectives.C.Parent = nil
    end

    local warnings, prints, notices, loaded = {}, {}, {}, {}
    local noop = function() end
    local savedModule = { Name = "LiveMap", Authored = {}, Terrain = { GroundMaterial = Enum.Material.Grass } }
    local mapsFolder = {
        FindFirstChild = function(_, name)
            if name == "SnowFortress" then
                return { Name = name, IsA = function()
                    return true
                end, module = { Name = name } }
            end
            if name == "LiveMap" and opts.saved then
                return { Name = "LiveMap", IsA = function()
                    return true
                end, module = savedModule }
            end
            return nil
        end,
        GetChildren = function()
            return {}
        end,
        Validate = "Validate",
        Lobby = "Lobby",
    }
    local storage = {
        Packages = { Knit = "Knit" },
        Shared = {
            Palette = "Palette",
            Config = "Config",
            Uploads = "Uploads",
            MapAuthoring = "MapAuthoring",
            Maps = mapsFolder,
        },
    }
    local modules = {
        Knit = {
            CreateService = function(definition)
                return definition
            end,
            GetService = function(name)
                if name == "SafetyService" then
                    return {
                        Client = {
                            Notice = {
                                Fire = function(_, _, text)
                                    table.insert(notices, text)
                                end,
                                FireAll = noop,
                            },
                        },
                    }
                end
                return { EnsureSetup = noop }
            end,
        },
        Palette = { World = { Red = Color3.new(1, 0, 0), Blue = Color3.new(0, 0, 1) } },
        Config = { StartupMap = "SnowFortress" },
        Uploads = {},
        Validate = Validate,
        MapAuthoring = MapAuthoring,
    }
    local players = {
        GetPlayers = function()
            return {}
        end,
        GetPlayerFromCharacter = function()
            return nil
        end,
        PlayerAdded = { Connect = noop },
    }
    local MapService = luau.load(fs.readFile("src/server/Services/MapService.lua"), {
        debugName = "MapService live-map harness",
        injectGlobals = true,
        environment = {
            game = {
                GetService = function(_, name)
                    if name == "Players" then
                        return players
                    elseif name == "ReplicatedStorage" then
                        return storage
                    elseif name == "RunService" then
                        return {
                            IsStudio = function()
                                return opts.studio ~= false
                            end,
                        }
                    end
                    return {}
                end,
            },
            workspace = workspace,
            require = function(target)
                if type(target) == "table" and target.module then
                    return target.module
                end
                if target == "Lobby" then
                    -- the map has been chosen and loaded by now; the lobby is not under test
                    error("LOBBY_REACHED", 0)
                end
                return assert(modules[target], tostring(target))
            end,
            Instance = roblox.Instance,
            Color3 = Color3,
            Enum = Enum,
            Vector3 = Vector3,
            CFrame = roblox.CFrame,
            warn = function(...)
                table.insert(warnings, table.concat({ ... }, " "))
            end,
            print = function(...)
                table.insert(prints, table.concat({ ... }, " "))
            end,
            task = { delay = noop, defer = noop, wait = noop, spawn = noop },
        },
    })()
    -- Stop at the build: this harness checks the choice of map, not the world it makes.
    MapService.Build = function(_, layout)
        table.insert(loaded, layout)
    end
    local ok, why = pcall(MapService.KnitInit, MapService)
    assert(not ok and why == "LOBBY_REACHED", "KnitInit stopped early: " .. tostring(why))
    return {
        service = MapService,
        workspace = workspace,
        warnings = table.concat(warnings, "\n"),
        prints = table.concat(prints, "\n"),
        loaded = loaded,
    }
end

local r = run({})
check("a map in Workspace is read live and becomes the startup map", r.service.CurrentMap == "LiveMap", r.warnings)
check("the player is sent onto it, not the lobby", r.service.ExploreMap == "LiveMap")
local layout = r.loaded[1]
check(
    "the live layout has the template's objectives and spawns",
    layout and #layout.Objectives == 3 and #layout.Spawns.Blue == 6 and layout.Revision == "live"
)
check("the map model is removed from the play session", r.workspace:FindFirstChild("LiveMap — EDITABLE") == nil)
check(
    "a piece inside Geometry is part of the live map",
    r.service.GetLayout and r.service:FindMap("livemap") == "LiveMap"
)
check(
    "loose pieces are left out and named in Output",
    r.workspace:FindFirstChild("Fortress") == nil
        and r.warnings:find("Fortress", 1, true) ~= nil
        and r.warnings:find("Pallet", 1, true) ~= nil,
    r.warnings
)
check("the camera is not treated as a loose piece", r.workspace:FindFirstChildOfClass("Camera") ~= nil)

r = run({ saved = true })
check("a live map beats the saved module of the same name", r.loaded[1] and r.loaded[1].Revision == "live")
check(
    "it keeps the saved sky/terrain choices",
    r.loaded[1] and r.loaded[1].Terrain.GroundMaterial == Enum.Material.Grass
)

r = run({ breakIt = true })
check("a broken map is not played", r.service.ExploreMap == nil and r.service.CurrentMap == "SnowFortress")
check(
    "its problems are printed in plain language",
    r.warnings:find("can't be played yet", 1, true) ~= nil and r.warnings:find("exactly 3 objectives", 1, true) ~= nil,
    r.warnings
)

r = run({ studio = false })
check(
    "outside Studio a stray map model is removed and never played",
    r.service.CurrentMap == "SnowFortress" and r.workspace:FindFirstChild("LiveMap — EDITABLE") == nil
)

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    process.exit(1)
end
