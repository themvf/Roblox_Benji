-- Measures how the game runs on the device it is running on, so triangle and texture
-- budgets rest on numbers instead of guesses. Off unless Tuning.Debug_PerfProbe is true.
--
-- Every WINDOW seconds it sends the server one summary: frame rate (average and the slow
-- end), memory (total, textures, meshes), triangles and draw calls in view, and ping. The
-- server adds the map and player count and saves the session; see PerfProbeService and
-- docs/design/performance/DEVICE_TEST.md.
--
-- It also posts each summary as a system line in chat, so a screenshot of the chat window
-- is a usable record when nothing else is to hand.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TextChatService = game:GetService("TextChatService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)

local PerfProbeController = Knit.CreateController({ Name = "PerfProbeController" })

local WINDOW = 30 -- seconds per summary
local SLOW_SHARE = 0.01 -- "low" frame rate is the average of the slowest 1% of frames

local function tuning()
    return ReplicatedStorage:FindFirstChild("Tuning")
end

local function enabled()
    local t = tuning()
    return t ~= nil and t:GetAttribute("Debug_PerfProbe") == true
end

-- Stats properties and memory tags differ between client versions; a missing one reads as nil.
local function stat(name)
    local ok, value = pcall(function()
        return (Stats :: any)[name]
    end)
    return if ok and type(value) == "number" then value else nil
end

local function memoryTag(tag)
    local ok, value = pcall(function()
        return Stats:GetMemoryUsageMbForTag(tag)
    end)
    return if ok and type(value) == "number" then value else nil
end

local function round(value, places)
    if value == nil then
        return nil
    end
    local scale = 10 ^ (places or 0)
    return math.floor(value * scale + 0.5) / scale
end

local function device()
    local screen = Screen.get()
    local quality = nil
    pcall(function()
        quality = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
    end)
    return {
        class = screen.Class,
        touch = screen.Touch,
        viewportX = math.floor(screen.Viewport.X),
        viewportY = math.floor(screen.Viewport.Y),
        qualityLevel = quality, -- 0 means Automatic: Roblox is choosing, and lowering it under load
    }
end

local function say(text)
    pcall(function()
        local channels = TextChatService:FindFirstChild("TextChannels")
        local general = channels and channels:FindFirstChild("RBXGeneral")
        if general then
            general:DisplaySystemMessage(text)
        end
    end)
end

function PerfProbeController:KnitStart()
    local service = Knit.GetService("PerfProbeService")
    local frames = {} -- seconds per frame in the current window
    local samples = {} -- one-per-second readings of the slower-moving numbers
    local windowStart = os.clock()
    local sinceSample = 0
    local announced = false

    local function summarise()
        table.sort(frames)
        local count = #frames
        if count < 30 then
            return nil
        end
        local total = 0
        for _, dt in frames do
            total += dt
        end
        local slowCount = math.max(1, math.floor(count * SLOW_SHARE))
        local slowTotal = 0
        for i = count - slowCount + 1, count do
            slowTotal += frames[i]
        end
        local summary = {
            seconds = round(os.clock() - windowStart, 1),
            fpsAvg = round(count / total, 1),
            fpsLow = round(slowCount / slowTotal, 1),
            worstFrameMs = round(frames[count] * 1000, 1),
        }
        -- For each slow-moving number keep the average and the peak over the window.
        local keys =
            { "memoryMb", "textureMb", "meshMb", "triangles", "drawCalls", "shadowDrawCalls", "pingMs", "instances" }
        for _, key in keys do
            local sum, peak, n = 0, nil, 0
            for _, sample in samples do
                local value = sample[key]
                if value ~= nil then
                    sum += value
                    n += 1
                    peak = if peak == nil then value else math.max(peak, value)
                end
            end
            if n > 0 then
                summary[key .. "Avg"] = round(sum / n, 1)
                summary[key .. "Max"] = round(peak, 1)
            end
        end
        return summary
    end

    RunService.RenderStepped:Connect(function(dt)
        if not enabled() then
            if announced then
                announced = false
                table.clear(frames)
                table.clear(samples)
            end
            return
        end
        if not announced then
            announced = true
            windowStart = os.clock()
            sinceSample = 0
            say(("[Perf] recording on a %s, one line every %d seconds."):format(Screen.get().Class, WINDOW))
        end
        table.insert(frames, dt)
        sinceSample += dt
        if sinceSample >= 1 then
            sinceSample = 0
            local ping = nil
            pcall(function()
                ping = Players.LocalPlayer:GetNetworkPing() * 1000
            end)
            table.insert(samples, {
                memoryMb = Stats:GetTotalMemoryUsageMb(),
                textureMb = memoryTag(Enum.DeveloperMemoryTag.GraphicsTexture),
                meshMb = memoryTag(Enum.DeveloperMemoryTag.GraphicsMeshParts),
                triangles = stat("SceneTriangleCount"),
                drawCalls = stat("SceneDrawcallCount"),
                shadowDrawCalls = stat("ShadowsDrawcallCount"),
                pingMs = ping,
                instances = stat("InstanceCount"),
            })
        end
        if os.clock() - windowStart >= WINDOW then
            local summary = summarise()
            table.clear(frames)
            table.clear(samples)
            windowStart = os.clock()
            if summary then
                say(
                    ("[Perf] %s fps (low %s), %s MB, %s tris, %s draws"):format(
                        tostring(summary.fpsAvg),
                        tostring(summary.fpsLow),
                        tostring(summary.memoryMbAvg),
                        tostring(summary.trianglesAvg or "?"),
                        tostring(summary.drawCallsAvg or "?")
                    )
                )
                service:Report(device(), summary):catch(warn)
            end
        end
    end)
end

return PerfProbeController
