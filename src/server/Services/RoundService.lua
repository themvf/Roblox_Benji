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
function RoundService:StartMatch(players, teamSize, mode)
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

    task.spawn(function()
        self:Broadcast("Intermission", { Time = Config.IntermissionSeconds, Mode = mode })
        task.wait(Config.IntermissionSeconds)

        local aborted = false
        repeat
            local _, abort = self:RunRound(match)
            aborted = abort
        until aborted
            or match.Score.Red >= Config.RoundsToWin
            or match.Score.Blue >= Config.RoundsToWin

        self:Broadcast("MatchOver", { Score = match.Score, Mode = mode, Aborted = aborted })
        task.wait(aborted and 1 or 6)

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
    end

    Players.PlayerAdded:Connect(onPlayer)
    for _, p in Players:GetPlayers() do
        onPlayer(p)
    end
end

return RoundService
