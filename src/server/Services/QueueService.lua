-- Matchmaking pads. Each mode pad has a Red half and a Blue half; standing on a half
-- queues you for that mode on that team. When both halves hold teamSize players and no
-- match is running, those players are handed to RoundService (Red first, then Blue).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local QueueService = Knit.CreateService({ Name = "QueueService" })

local fillSince = {} -- [pad] = os.clock() when both sides first reached MinTeamSize
local lastConvergenceMap = nil

local function pickConvergenceMap()
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    local forced = tuning and tuning:GetAttribute("Debug_ForceMap")
    if tuning and tuning:GetAttribute("Debug_CarrierTestSafety") == true and (forced == nil or forced == "") then
        forced = "Carrier"
    end
    if type(forced) == "string" and forced ~= "" and ReplicatedStorage.Shared.Maps:FindFirstChild(forced) then
        lastConvergenceMap = forced
        return forced
    end
    local choices = {}
    for _, name in Config.ConvergenceMaps or { "Forest" } do
        if name ~= lastConvergenceMap or #Config.ConvergenceMaps == 1 then
            table.insert(choices, name)
        end
    end
    lastConvergenceMap = choices[math.random(#choices)]
    return lastConvergenceMap
end

local CHECK_INTERVAL = 0.25

local function onPad(root, pad)
    local rel = pad.CFrame:PointToObjectSpace(root.Position)
    return math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2 and rel.Y > -2 and rel.Y < 8
end

local function byJoinOrder(a, b)
    return a.UserId < b.UserId
end

function QueueService:KnitStart()
    local MapService = Knit.GetService("MapService")
    local RoundService = Knit.GetService("RoundService")

    task.spawn(function()
        while true do
            task.wait(CHECK_INTERVAL)
            local pads = MapService.Pads
            if not pads then
                continue
            end
            for _, pad in pads do
                local queued = { Red = {}, Blue = {} }
                for _, player in Players:GetPlayers() do
                    if player:GetAttribute("InMatch") then
                        continue
                    end
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        for team, part in pad.Sides do
                            if onPad(root, part) then
                                table.insert(queued[team], player)
                            end
                        end
                    end
                end

                local need = pad.TeamSize
                local minNeed = pad.MinTeamSize or need
                local red, blue = #queued.Red, #queued.Blue
                local full = red >= need and blue >= need
                local viable = red >= minNeed and blue >= minNeed
                local rules = Config.GetConvergence()
                local waitLeft = nil
                if viable and not full and pad.Kind == "Convergence" then
                    fillSince[pad] = fillSince[pad] or os.clock()
                    waitLeft = math.max(0, rules.FillWaitSeconds - (os.clock() - fillSince[pad]))
                else
                    fillSince[pad] = nil
                end

                local status
                if RoundService.Busy then
                    status = "Match in progress"
                elseif full then
                    status = "Starting..."
                elseif waitLeft then
                    status = ("Red %d   Blue %d   starting in %ds (or when full)"):format(
                        red,
                        blue,
                        math.ceil(waitLeft)
                    )
                elseif red == 0 and blue == 0 then
                    status = minNeed < need and ("Pick a side  (%d-%d per team)"):format(minNeed, need)
                        or ("Pick a side  (%d per team)"):format(need)
                else
                    status = ("Red %d/%d   Blue %d/%d"):format(math.min(red, need), need, math.min(blue, need), need)
                end
                pad.Label.Text = pad.Mode .. "\n" .. status

                local go = not RoundService.Busy and (full or (waitLeft ~= nil and waitLeft <= 0))
                if go then
                    fillSince[pad] = nil
                    table.sort(queued.Red, byJoinOrder)
                    table.sort(queued.Blue, byJoinOrder)
                    local n = math.min(red, blue, need) -- balanced teams
                    local picked = {}
                    for i = 1, n do
                        table.insert(picked, queued.Red[i])
                    end
                    for i = 1, n do
                        table.insert(picked, queued.Blue[i])
                    end
                    -- The mode assigns the first n players to Red, the rest to Blue
                    if pad.Kind == "Convergence" then
                        Knit.GetService("ConvergenceService"):StartMatch(picked, n, pickConvergenceMap())
                    else
                        RoundService:StartMatch(picked, n, pad.Mode)
                    end
                end
            end
        end
    end)
end

return QueueService
