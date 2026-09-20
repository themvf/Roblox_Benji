-- Execute the real service against the current queue-to-mode API contract.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/Config")
local source = fs.readFile("src/server/Services/ConvergenceService.lua")

for _, loadSucceeds in { true, false } do
    local loaded, aborted, failures = nil, false, {}
    local players = {}
    local noop = function() end
    local services = {
        RoundService = { Busy = false, Broadcast = noop },
        BotService = { Stop = noop },
        StatsService = {
            StartMatch = noop,
            Abort = function()
                aborted = true
            end,
        },
        MutationService = { StartMatch = noop, EndMatch = noop },
        AbilityService = { ResetTelemetry = noop },
        PickupService = { Stats = {} },
        -- Deliberately no obsolete Pick method: queue has already selected the map.
        MapVoteService = { Begin = noop },
        MapService = {
            Objectives = {}, -- stops after entry preflight without simulating combat
            Load = function(_, name)
                loaded = name
                return loadSucceeds
            end,
        },
    }
    local modules = {
        Knit = {
            CreateService = function(definition)
                return definition
            end,
            CreateSignal = function()
                return { Fire = noop }
            end,
            GetService = function(name)
                return assert(services[name], name)
            end,
        },
        Palette = { Ui = { Red = roblox.Color3.new(1, 0, 0), Blue = roblox.Color3.new(0, 0, 1) } },
        Config = Config,
        FinalePlan = {
            create = function()
                return nil
            end,
        },
        Chosen = { Objectives = {} },
    }
    local storage = {
        Packages = { Knit = "Knit" },
        Shared = {
            Palette = "Palette",
            Config = "Config",
            Maps = { SnowFortress = "Chosen" },
        },
    }
    local service = luau.load(source, {
        debugName = "ConvergenceService entry regression",
        injectGlobals = true,
        environment = {
            game = {
                GetService = function(_, name)
                    if name == "Players" then
                        return players
                    end
                    if name == "ReplicatedStorage" then
                        return storage
                    end
                    return {}
                end,
            },
            script = { Parent = { Parent = { FinalePlan = "FinalePlan" } } },
            require = function(name)
                return assert(modules[name], name)
            end,
            Color3 = roblox.Color3,
            Enum = roblox.Enum,
            task = {
                spawn = function(callback)
                    callback()
                end,
                wait = noop,
            },
            warn = function(message)
                table.insert(failures, message)
            end,
            print = noop,
        },
    })()
    assert(service:StartMatch({}, 0, "SnowFortress"), "start request accepted")
    assert(loaded == "SnowFortress", "queue-selected map must reach MapService without a second vote")
    assert(aborted, "failed/empty map aborts instead of hanging")
    assert(not service.Busy and not services.RoundService.Busy and service.Match == nil, "lobby locks released")
    if not loadSucceeds then
        assert(tostring(failures[1]):find("Could not load Convergence map"), "failed load reports its cause")
    end
end
print("PASS: queue-selected map reaches loader; failed/empty maps release Convergence and lobby locks")
