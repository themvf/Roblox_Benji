-- Lobby matchmaking. Players may queue from the persistent PLAY menu or by standing
-- on a physical team pad. Both routes feed the same server-owned queue state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local QueueService = Knit.CreateService({
    Name = "QueueService",
    Client = {
        Changed = Knit.CreateSignal(), -- ({ public mode status })
    },
})

local fillSince = {} -- [pad] = os.clock() when both sides first reached MinTeamSize
local menuQueue = {} -- [player] = { Mode, Team }
local physicalQueued = {} -- players queued by a pad on the previous scan
local lastStatusSignature = ""

local CHECK_INTERVAL = 0.25

local function onPad(root, pad)
    local rel = pad.CFrame:PointToObjectSpace(root.Position)
    return math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2 and rel.Y > -2 and rel.Y < 8
end

local function byJoinOrder(a, b)
    return a.UserId < b.UserId
end

local function setQueueAttributes(player, state, mode, team)
    player:SetAttribute("QueueState", state)
    player:SetAttribute("QueuedMode", mode)
    player:SetAttribute("QueuedTeam", team)
end

local function clearMenuQueue(player, state)
    menuQueue[player] = nil
    setQueueAttributes(player, state or "Lobby", nil, nil)
end

local function findPad(mode)
    local mapService = Knit.GetService("MapService")
    for _, pad in mapService.Pads or {} do
        if pad.Mode == mode then
            return pad
        end
    end
    return nil
end

function QueueService.Client:GetStatus(player)
    return self.Server.Statuses or {}, player:GetAttribute("QueuedMode"), player:GetAttribute("QueuedTeam")
end

function QueueService.Client:Join(player, mode, team)
    if player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed" then
        return false, "match_locked"
    end
    if type(mode) ~= "string" or (team ~= "Red" and team ~= "Blue") or not findPad(mode) then
        return false, "invalid_queue"
    end
    menuQueue[player] = { Mode = mode, Team = team }
    setQueueAttributes(player, "Queued", mode, team)
    return true
end

function QueueService.Client:Leave(player)
    if player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed" then
        return false, "match_locked"
    end
    clearMenuQueue(player)
    return true
end

local function publicStatus(pad, red, blue, status)
    return {
        Mode = pad.Mode,
        Kind = pad.Kind,
        TeamSize = pad.TeamSize,
        MinTeamSize = pad.MinTeamSize,
        Red = red,
        Blue = blue,
        Status = status,
    }
end

local function publishStatus(self, statuses)
    local parts = {}
    for _, status in statuses do
        table.insert(parts, table.concat({ status.Mode, status.Red, status.Blue, status.TeamSize, status.Status }, "|"))
    end
    local signature = table.concat(parts, ";")
    self.Statuses = statuses
    if signature ~= lastStatusSignature then
        lastStatusSignature = signature
        self.Client.Changed:FireAll(statuses)
    end
end

local function watchPlayer(player)
    setQueueAttributes(player, "Lobby", nil, nil)
    player:GetAttributeChangedSignal("InMatch"):Connect(function()
        if player:GetAttribute("InMatch") then
            return
        end
        if player:GetAttribute("QueueState") == "Committed" then
            setQueueAttributes(player, "Lobby", nil, nil)
        end
    end)
end

function QueueService:KnitStart()
    local MapService = Knit.GetService("MapService")
    local RoundService = Knit.GetService("RoundService")
    local MapVoteService = Knit.GetService("MapVoteService")

    Players.PlayerAdded:Connect(watchPlayer)
    Players.PlayerRemoving:Connect(function(player)
        menuQueue[player] = nil
        physicalQueued[player] = nil
    end)
    for _, player in Players:GetPlayers() do
        watchPlayer(player)
    end

    task.spawn(function()
        while true do
            task.wait(CHECK_INTERVAL)
            local pads = MapService.Pads
            if not pads then
                continue
            end

            local statuses = {}
            local physicalNow = {}
            local committedThisTick = {}
            for _, pad in pads do
                local queued = { Red = {}, Blue = {} }
                for _, player in Players:GetPlayers() do
                    if player:GetAttribute("InMatch") then
                        continue
                    end
                    local selected = menuQueue[player]
                    if selected and selected.Mode == pad.Mode then
                        table.insert(queued[selected.Team], player)
                    elseif not selected then
                        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            for team, part in pad.Sides do
                                if onPad(root, part) then
                                    table.insert(queued[team], player)
                                    physicalNow[player] = { Mode = pad.Mode, Team = team }
                                    break
                                end
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
                if MapVoteService.Voting then
                    status = "Map vote in progress"
                elseif RoundService.Busy then
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
                table.insert(statuses, publicStatus(pad, red, blue, status))

                local go = not RoundService.Busy
                    and not MapVoteService.Voting
                    and (full or (waitLeft ~= nil and waitLeft <= 0))
                if go then
                    fillSince[pad] = nil
                    table.sort(queued.Red, byJoinOrder)
                    table.sort(queued.Blue, byJoinOrder)
                    local n = math.min(red, blue, need)
                    local picked = {}
                    for i = 1, n do
                        table.insert(picked, queued.Red[i])
                    end
                    for i = 1, n do
                        table.insert(picked, queued.Blue[i])
                    end
                    -- The players who filled the pad vote on the map, then the mode starts with
                    -- the winner. The mode assigns the first n players to Red, the rest to Blue.
                    for _, player in picked do
                        menuQueue[player] = nil
                        physicalNow[player] = nil
                        committedThisTick[player] = true
                    end
                    local kind, mode = pad.Kind, pad.Mode
                    MapVoteService:Begin(picked, n, kind, function(players, teamSize, mapName)
                        for _, player in players do
                            menuQueue[player] = nil
                            setQueueAttributes(player, "Committed", nil, nil)
                        end
                        if kind == "Convergence" then
                            Knit.GetService("ConvergenceService"):StartMatch(players, teamSize, mapName)
                        else
                            RoundService:StartMatch(players, teamSize, mode, mapName)
                        end
                    end)
                end
            end

            for player in physicalQueued do
                if
                    not physicalNow[player]
                    and not menuQueue[player]
                    and not player:GetAttribute("InMatch")
                    and not committedThisTick[player]
                then
                    setQueueAttributes(player, "Lobby", nil, nil)
                end
            end
            for player, selection in physicalNow do
                if not committedThisTick[player] then
                    setQueueAttributes(player, "Queued", selection.Mode, selection.Team)
                end
            end
            physicalQueued = physicalNow
            publishStatus(self, statuses)
        end
    end)
end

return QueueService
