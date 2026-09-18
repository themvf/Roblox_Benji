-- Matchmaking pads. Each mode pad has a Red half and a Blue half; standing on a half
-- queues you for that mode on that team. When both halves hold teamSize players and no
-- match is running, those players are handed to RoundService (Red first, then Blue).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QueueService = Knit.CreateService({ Name = "QueueService" })

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
                local red, blue = #queued.Red, #queued.Blue
                local status
                if RoundService.Busy then
                    status = "Match in progress"
                elseif red >= need and blue >= need then
                    status = "Starting..."
                elseif red == 0 and blue == 0 then
                    status = ("Pick a side  (%d per team)"):format(need)
                else
                    status = ("Red %d/%d   Blue %d/%d"):format(math.min(red, need), need, math.min(blue, need), need)
                end
                pad.Label.Text = pad.Mode .. "\n" .. status

                if red >= need and blue >= need and not RoundService.Busy then
                    table.sort(queued.Red, byJoinOrder)
                    table.sort(queued.Blue, byJoinOrder)
                    local picked = {}
                    for i = 1, need do
                        table.insert(picked, queued.Red[i])
                    end
                    for i = 1, need do
                        table.insert(picked, queued.Blue[i])
                    end
                    -- RoundService assigns the first teamSize players to Red, the rest to Blue
                    RoundService:StartMatch(picked, pad.TeamSize, pad.Mode)
                end
            end
        end
    end)
end

return QueueService
