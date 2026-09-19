-- Runs one match at a time for a set of players handed over by QueueService:
-- countdown -> rounds until a team reaches RoundsToWin -> everyone back to the lobby.
-- Players not in a match live in the lobby (Team attribute "Lobby").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local RoundService = Knit.CreateService({
    Name = "RoundService",
    Client = {
        StateChanged = Knit.CreateSignal(), -- (state: string, data: table)
    },
})

RoundService.Busy = false
RoundService.Match = nil -- { Players = {}, Score = {Red=,Blue=}, Mode = "1v1" }

function RoundService:Broadcast(state, data)
    self.Client.StateChanged:FireAll(state, data or {})
end

function RoundService:SendToLobby(player)
    player:SetAttribute("InMatch", nil)
    player:SetAttribute("Team", "Lobby")
    if player.Parent then
        player:LoadCharacter()
    end
end

-- Players still connected and still part of this match
local function present(match)
    local out = {}
    for _, p in match.Players do
        if p.Parent == Players then
            table.insert(out, p)
        end
    end
    return out
end

local function alive(match, team)
    local n = 0
    for _, p in present(match) do
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if p:GetAttribute("Team") == team and hum and hum.Health > 0 then
            n += 1
        end
    end
    return n
end

local function teamCount(match, team)
    local n = 0
    for _, p in present(match) do
        if p:GetAttribute("Team") == team then
            n += 1
        end
    end
    return n
end

function RoundService:RunRound(match)
    for _, p in present(match) do
        p:LoadCharacter()
    end
    self:Broadcast("Round", { Score = match.Score, Time = Config.RoundSeconds, Mode = match.Mode })

    local deadline = os.clock() + Config.RoundSeconds
    local winner
    while os.clock() < deadline do
        local red, blue = alive(match, "Red"), alive(match, "Blue")
        if teamCount(match, "Red") == 0 or teamCount(match, "Blue") == 0 then
            return nil, true -- a whole team left; abort the match
        end
        if red == 0 and blue > 0 then
            winner = "Blue"
            break
        end
        if blue == 0 and red > 0 then
            winner = "Red"
            break
        end
        task.wait(0.25)
    end

    if winner then
        match.Score[winner] += 1
    end
    self:Broadcast("RoundOver", { Winner = winner, Score = match.Score, Mode = match.Mode })
    task.wait(4)
    return winner, false
end

-- players: array of Player, already split so #players == teamSize * 2
-- Kills are attributed from the LastHitBy attribute that damage code sets on the character.
local function trackKills(match)
    local conns = {}
    for _, p in match.Players do
        p:SetAttribute("MatchKills", 0)
        table.insert(
            conns,
            p.CharacterAdded:Connect(function(character)
                local hum = character:WaitForChild("Humanoid")
                hum.Died:Connect(function()
                    local killerId = character:GetAttribute("LastHitBy")
                    local killer = killerId and Players:GetPlayerByUserId(killerId)
                    if killer and killer ~= p and killer:GetAttribute("InMatch") then
                        killer:SetAttribute("MatchKills", (killer:GetAttribute("MatchKills") or 0) + 1)
                    end
                end)
            end)
        )
    end
    return conns
end

-- `votedMap` comes from the lobby map vote (MapVoteService). Without one, keep the old
-- random-but-never-twice-in-a-row pick, so a direct call still works.
function RoundService:StartMatch(players, teamSize, mode, votedMap)
    if self.Busy then
        return false
    end
    self.Busy = true
    local match = { Players = players, Score = { Red = 0, Blue = 0 }, Mode = mode }
    self.Match = match

    for i, player in players do
        player:SetAttribute("InMatch", true)
        player:SetAttribute("Team", i <= teamSize and "Red" or "Blue")
    end
    local killConns = trackKills(match)

    task.spawn(function()
        local MapService = Knit.GetService("MapService")
        local mapName = votedMap
        if not mapName then
            -- Map variation: random pick, never the same map twice in a row
            local choices = {}
            for _, name in Config.Maps or { MapService.CurrentMap } do
                if name ~= self.LastMap or #Config.Maps == 1 then
                    table.insert(choices, name)
                end
            end
            mapName = choices[math.random(#choices)]
        end
        self.LastMap = mapName
        self:Broadcast("Intermission", { Time = Config.IntermissionSeconds, Mode = mode, Map = mapName })
        MapService:Load(mapName)
        task.wait(Config.IntermissionSeconds)

        local aborted = false
        repeat
            local _, abort = self:RunRound(match)
            aborted = abort
        until aborted
            or match.Score.Red >= Config.RoundsToWin
            or match.Score.Blue >= Config.RoundsToWin

        self:Broadcast("MatchOver", { Score = match.Score, Mode = mode, Aborted = aborted })

        if not aborted then
            -- Winners in MVP order (most kills first), losers watch, then the podium sequence
            local winTeam = match.Score.Red > match.Score.Blue and "Red" or "Blue"
            local winners, losers = {}, {}
            for _, p in present(match) do
                if p:GetAttribute("Team") == winTeam then
                    table.insert(winners, p)
                else
                    table.insert(losers, p)
                end
            end
            table.sort(winners, function(a, b)
                local ka, kb = a:GetAttribute("MatchKills") or 0, b:GetAttribute("MatchKills") or 0
                if ka ~= kb then
                    return ka > kb
                end
                return a.UserId < b.UserId
            end)
            -- Lifetime stats (DataService mirrors these attributes into the profile)
            for _, p in present(match) do
                p:SetAttribute("Matches", (p:GetAttribute("Matches") or 0) + 1)
                p:SetAttribute("Kills", (p:GetAttribute("Kills") or 0) + (p:GetAttribute("MatchKills") or 0))
            end
            for _, p in winners do
                p:SetAttribute("Wins", (p:GetAttribute("Wins") or 0) + 1)
            end
            Knit.GetService("CelebrationService"):Run(winners, losers)
        else
            task.wait(1)
        end

        for _, c in killConns do
            c:Disconnect()
        end
        for _, p in present(match) do
            self:SendToLobby(p)
        end
        self.Match = nil
        self.Busy = false
        self:Broadcast("Lobby", {})
    end)
    return true
end

function RoundService:KnitStart()
    Players.CharacterAutoLoads = false -- we decide where and when characters spawn

    local function onPlayer(player)
        -- Let DataService load the profile first so the first spawn has the saved loadout
        local t0 = os.clock()
        while player.Parent and not player:GetAttribute("DataLoaded") and os.clock() - t0 < 15 do
            task.wait(0.1)
        end
        if not player.Parent then
            return
        end
        player:SetAttribute("Team", "Lobby")
        player.CharacterAdded:Connect(function(character)
            local hum = character:WaitForChild("Humanoid")
            hum.Died:Connect(function()
                -- Lobby deaths respawn; match deaths wait for the next round
                if not player:GetAttribute("InMatch") then
                    task.wait(Config.RespawnSeconds)
                    if player.Parent and not player:GetAttribute("InMatch") then
                        player:LoadCharacter()
                    end
                end
            end)
        end)
        player:LoadCharacter()
        task.defer(function()
            self.Client.StateChanged:Fire(player, "Lobby", {})
        end)
        -- /map <name|off>: force the next Convergence map (dev)
        player.Chatted:Connect(function(msg)
            local name = msg:match("^/map%s+(%a+)")
            if name then
                local tuning = ReplicatedStorage:FindFirstChild("Tuning")
                local pretty = name:sub(1, 1):upper() .. name:sub(2):lower()
                if tuning and (pretty == "Off" or pretty == "None") then
                    tuning:SetAttribute("Debug_ForceMap", "")
                    Knit.GetService("SafetyService").Client.Notice:Fire(player, "Map override off: normal rotation")
                elseif tuning and ReplicatedStorage.Shared.Maps:FindFirstChild(pretty) then
                    tuning:SetAttribute("Debug_ForceMap", pretty)
                    Knit.GetService("SafetyService").Client.Notice
                        :Fire(player, "Next Convergence map forced to: " .. pretty)
                else
                    Knit.GetService("SafetyService").Client.Notice:Fire(player, "Unknown map: " .. name)
                end
            end
        end)
        -- Lobby preview: type /celebrate to run your default celebration solo on the podium
        player.Chatted:Connect(function(msg)
            if msg:lower():sub(1, 10) == "/celebrate" and not player:GetAttribute("InMatch") and not self.Busy then
                self.Busy = true
                Knit.GetService("CelebrationService"):Run({ player }, {})
                self.Busy = false
                if player.Parent then
                    self:SendToLobby(player)
                end
            end
        end)
    end

    Players.PlayerAdded:Connect(onPlayer)
    for _, p in Players:GetPlayers() do
        onPlayer(p)
    end
end

return RoundService
