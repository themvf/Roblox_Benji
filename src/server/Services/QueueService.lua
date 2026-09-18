-- Matchmaking pads. Standing on a pad puts you in that mode's queue; when the
-- queue fills and no match is running, those players are handed to RoundService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QueueService = Knit.CreateService({ Name = "QueueService" })

local CHECK_INTERVAL = 0.25

local function onPad(root, pad)
    local rel = pad.CFrame:PointToObjectSpace(root.Position)
    return math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2 and rel.Y > -2 and rel.Y < 8
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
                local queued = {}
                for _, player in Players:GetPlayers() do
                    if player:GetAttribute("InMatch") then
                        continue
                    end
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root and onPad(root, pad.Part) then
                        table.insert(queued, player)
                    end
                end

                local need = pad.TeamSize * 2
                local status
                if RoundService.Busy then
                    status = "Match in progress"
                elseif #queued >= need then
                    status = "Starting..."
                elseif #queued == 0 then
                    status = ("Stand here  (%d players)"):format(need)
                else
                    local more = need - #queued
                    status = ("%d / %d  needs %d more"):format(#queued, need, more)
                end
                pad.Label.Text = pad.Mode .. "\n" .. status

                if #queued >= need and not RoundService.Busy then
                    -- Sort so queue order is stable: earliest joiners first
                    table.sort(queued, function(a, b)
                        return a.UserId < b.UserId
                    end)
                    local picked = {}
                    for i = 1, need do
                        picked[i] = queued[i]
                    end
                    RoundService:StartMatch(picked, pad.TeamSize, pad.Mode)
                end
            end
        end
    end)
end

return QueueService
