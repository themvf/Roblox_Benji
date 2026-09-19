-- Lobby map vote. Once a pad fills, the players who filled it pick the next map before the match
-- starts, instead of the server choosing at random.
--
-- Where it sits: QueueService used to call pickConvergenceMap() and hand the name straight to the
-- mode. That name is now decided here, and the mode's own "Intermission" broadcast still happens
-- afterwards -- by then the map is already loaded, which is why the vote cannot live there.
--
-- Server-authoritative: the client only ever sends an index into the candidate list this service
-- published, and only players in the voter set for the open round are counted.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local MapVoteService = Knit.CreateService({
    Name = "MapVoteService",
    Client = {
        -- (maps: {string}, seconds: number) to the voters when a vote opens
        Opened = Knit.CreateSignal(),
        -- (counts: {number}) after every vote, to the voters
        Tally = Knit.CreateSignal(),
        -- (winner: string) when it closes, to the voters
        Closed = Knit.CreateSignal(),
    },
})

MapVoteService.Voting = false -- QueueService checks this so a second pad cannot start meanwhile

local lastMap = {} -- [poolKey] = the map that just played, kept out of the next candidate list

local function tuning()
    return ReplicatedStorage:FindFirstChild("Tuning")
end

-- A forced map skips the vote entirely: /map carrier has to keep meaning carrier.
--
-- Debug_CarrierTestSafety used to force the Carrier here too, which is why Convergence always
-- played the Carrier in a dev session. That switch now means "testing aids" and nothing else --
-- with it still forcing a map, the vote would never appear in the default Studio config. Use
-- /map carrier (Debug_ForceMap) when you want to pin the map.
local function forcedMap()
    local t = tuning()
    local forced = t and t:GetAttribute("Debug_ForceMap")
    if type(forced) == "string" and forced ~= "" and ReplicatedStorage.Shared.Maps:FindFirstChild(forced) then
        return forced
    end
    return nil
end

local function pool(kind)
    if kind == "Convergence" then
        return Config.ConvergenceMaps or { "Forest" }, "Convergence"
    end
    return Config.Maps or { "Forest" }, "Duel"
end

-- Candidates: a random sample of the mode's rotation. The map that just played is dropped, but
-- only while that still leaves a full ballot -- with a three-map rotation and three options,
-- excluding it would offer two cards every time, and a player who wants a rematch should be able
-- to vote for one. The old no-repeat rule existed to stop *random* picking the same map twice;
-- a vote is a choice.
local function candidates(kind)
    local maps, key = pool(kind)
    local want = math.clamp(tonumber(Config.MapVoteOptions) or 3, 1, #maps)
    local available = {}
    for _, name in maps do
        if name ~= lastMap[key] or #maps - 1 < want then
            table.insert(available, name)
        end
    end
    local picked = {}
    for _ = 1, math.min(want, #available) do
        table.insert(picked, table.remove(available, math.random(#available)))
    end
    return picked, key
end

local function tally(self)
    local counts = table.create(#self.Candidates, 0)
    for _, index in self.Votes do
        counts[index] = (counts[index] or 0) + 1
    end
    return counts
end

local function winner(self)
    local counts = tally(self)
    local best, leaders = 0, {}
    for i, n in counts do
        if n > best then
            best, leaders = n, { i }
        elseif n == best and n > 0 then
            table.insert(leaders, i)
        end
    end
    if #leaders == 0 then -- nobody voted
        return self.Candidates[math.random(#self.Candidates)]
    end
    return self.Candidates[leaders[math.random(#leaders)]] -- ties broken randomly
end

-- Players who filled the pad but left the game (or the server) during the vote should not be
-- handed to the mode. Returns the surviving Red/Blue split, balanced.
local function stillPresent(players, teamSize)
    local red, blue = {}, {}
    for i, player in players do
        if player.Parent then
            table.insert(i <= teamSize and red or blue, player)
        end
    end
    local n = math.min(#red, #blue)
    local out = {}
    for i = 1, n do
        table.insert(out, red[i])
    end
    for i = 1, n do
        table.insert(out, blue[i])
    end
    return out, n
end

function MapVoteService:Remember(kind, mapName)
    local _, key = pool(kind)
    lastMap[key] = mapName
end

-- Runs the vote, then calls onDecided(players, teamSize, mapName). Never blocks the caller.
-- onDecided is not called at all if too few players are left to field two sides.
function MapVoteService:Begin(players, teamSize, kind, onDecided)
    if self.Voting then
        return false
    end

    local forced = forcedMap()
    local seconds = tonumber(Config.MapVoteSeconds) or 12
    if forced or Config.MapVoteEnabled ~= true or seconds <= 0 then
        local name = forced or (candidates(kind))[1]
        self:Remember(kind, name)
        onDecided(players, teamSize, name)
        return true
    end

    local list, key = candidates(kind)
    if #list <= 1 then -- nothing to choose between
        self:Remember(kind, list[1])
        onDecided(players, teamSize, list[1])
        return true
    end

    self.Voting = true
    self.Candidates = list
    self.Votes = {}
    self.Voters = {}
    for _, player in players do
        self.Voters[player] = true
    end

    for _, player in players do
        if player.Parent then
            self.Client.Opened:Fire(player, list, seconds)
        end
    end

    task.spawn(function()
        local deadline = os.clock() + seconds
        while os.clock() < deadline and self.Voting do
            task.wait(0.25)
        end

        local name = winner(self)
        lastMap[key] = name
        for player in self.Voters do
            if player.Parent then
                self.Client.Closed:Fire(player, name)
            end
        end
        self.Voting = false
        self.Candidates, self.Votes, self.Voters = nil, nil, nil

        local remaining, n = stillPresent(players, teamSize)
        if n == 0 then
            warn("[MapVote] everyone left during the vote; match cancelled")
            return
        end
        onDecided(remaining, n, name)
    end)
    return true
end

function MapVoteService.Client:Vote(player, index)
    local svc = self.Server
    if not svc.Voting or not svc.Voters or not svc.Voters[player] then
        return false
    end
    if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #svc.Candidates then
        return false
    end
    svc.Votes[player] = index
    local counts = tally(svc)
    for voter in svc.Voters do
        if voter.Parent then
            svc.Client.Tally:Fire(voter, counts)
        end
    end
    return true
end

function MapVoteService:KnitStart()
    -- A player who leaves mid-vote should stop counting toward the tally.
    Players.PlayerRemoving:Connect(function(player)
        if self.Voting and self.Voters and self.Voters[player] then
            self.Voters[player] = nil
            self.Votes[player] = nil
        end
    end)
end

return MapVoteService
