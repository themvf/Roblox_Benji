-- Receives the performance summaries PerfProbeController sends, stamps each with what the
-- server knows (map, players, vehicles), and saves one record per player session to the
-- "PerfProbe_v1" data store. Off unless Tuning.Debug_PerfProbe is true.
--
-- Read the results back in Studio's command bar with the snippet in
-- docs/design/performance/DEVICE_TEST.md; tools/perf_report.py turns them into a table.
--
-- The numbers come from a client and are only ever used for our own reading, never for
-- gameplay. They are still filtered to a fixed list of numeric fields and capped in count,
-- so a tampered client cannot store arbitrary data.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PerfProbeService = Knit.CreateService({ Name = "PerfProbeService", Client = {} })

local STORE = "PerfProbe_v1"
local MAX_WINDOWS = 240 -- two hours of 30-second windows per session
local MIN_GAP = 10 -- seconds between accepted reports from one player
local SAVE_EVERY = 4 -- windows between saves, so a crash loses at most two minutes

local SUMMARY_FIELDS = { "seconds", "fpsAvg", "fpsLow", "worstFrameMs" }
for _, key in { "memoryMb", "textureMb", "meshMb", "triangles", "drawCalls", "shadowDrawCalls", "pingMs", "instances" } do
    table.insert(SUMMARY_FIELDS, key .. "Avg")
    table.insert(SUMMARY_FIELDS, key .. "Max")
end
local DEVICE_NUMBERS = { "viewportX", "viewportY", "qualityLevel" }
local DEVICE_CLASSES = { Phone = true, Tablet = true, Desktop = true, Console = true }

local sessions = {} -- [player] = { key, record, lastReport, unsaved }

local function enabled()
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    return tuning ~= nil and tuning:GetAttribute("Debug_PerfProbe") == true
end

local function numbers(source, fields)
    local out = {}
    if type(source) ~= "table" then
        return out
    end
    for _, key in fields do
        local value = source[key]
        if type(value) == "number" and value == value and math.abs(value) < 1e9 then
            out[key] = value
        end
    end
    return out
end

local function context()
    local map = nil
    local ok, mapService = pcall(Knit.GetService, "MapService")
    if ok and mapService then
        map = mapService.CurrentMap
    end
    local vehicles = 0
    for _, model in workspace:GetDescendants() do
        if model:IsA("VehicleSeat") and model.Name == "DriverSeat" then
            vehicles += 1
        end
    end
    return { map = map or "unknown", players = #Players:GetPlayers(), vehicles = vehicles }
end

local function save(session)
    if session.unsaved == 0 then
        return
    end
    session.unsaved = 0
    local ok, problem = pcall(function()
        DataStoreService:GetDataStore(STORE):SetAsync(session.key, session.record)
    end)
    if not ok then
        warn("[PerfProbe] could not save " .. session.key .. ": " .. tostring(problem))
    end
end

function PerfProbeService.Client:Report(player, device, summary)
    if not enabled() then
        return false
    end
    local now = os.time()
    local session = sessions[player]
    if not session then
        local clean = numbers(device, DEVICE_NUMBERS)
        clean.class = if type(device) == "table" and DEVICE_CLASSES[device.class] then device.class else "unknown"
        clean.touch = type(device) == "table" and device.touch == true
        session = {
            key = ("%s_%d"):format(os.date("!%Y%m%dT%H%M%S", now), player.UserId),
            record = {
                startedAt = now,
                userId = player.UserId,
                placeVersion = game.PlaceVersion,
                device = clean,
                windows = {},
            },
            lastReport = 0,
            unsaved = 0,
        }
        sessions[player] = session
    end
    if now - session.lastReport < MIN_GAP or #session.record.windows >= MAX_WINDOWS then
        return false
    end
    session.lastReport = now
    local window = numbers(summary, SUMMARY_FIELDS)
    for key, value in context() do
        window[key] = value
    end
    window.at = now
    table.insert(session.record.windows, window)
    session.unsaved += 1
    print(
        ("[PerfProbe] %s %s map=%s players=%d fps=%s low=%s mem=%sMB tris=%s draws=%s"):format(
            player.Name,
            session.record.device.class,
            tostring(window.map),
            window.players,
            tostring(window.fpsAvg),
            tostring(window.fpsLow),
            tostring(window.memoryMbAvg),
            tostring(window.trianglesAvg),
            tostring(window.drawCallsAvg)
        )
    )
    if session.unsaved >= SAVE_EVERY then
        task.spawn(save, session)
    end
    return true
end

function PerfProbeService:KnitStart()
    Players.PlayerRemoving:Connect(function(player)
        local session = sessions[player]
        sessions[player] = nil
        if session then
            save(session)
        end
    end)
    game:BindToClose(function()
        for _, session in sessions do
            save(session)
        end
    end)
end

return PerfProbeService
