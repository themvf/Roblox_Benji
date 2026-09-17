-- Runs the match loop: intermission -> assign teams -> round -> score -> repeat.
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

RoundService.Score = { Red = 0, Blue = 0 }
RoundService.State = "Waiting"

function RoundService:SetState(state, data)
    self.State = state
    self.Client.StateChanged:FireAll(state, data or {})
end

function RoundService:AssignTeams()
    local players = Players:GetPlayers()
    -- Fisher-Yates shuffle, then alternate teams
    for i = #players, 2, -1 do
        local j = math.random(i)
        players[i], players[j] = players[j], players[i]
    end
    for i, player in players do
        player:SetAttribute("Team", Config.Teams[(i % #Config.Teams) + 1])
    end
end

function RoundService:AlivePlayers(team)
    local n = 0
    for _, p in Players:GetPlayers() do
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if p:GetAttribute("Team") == team and hum and hum.Health > 0 then
            n += 1
        end
    end
    return n
end

function RoundService:RunRound()
    for _, p in Players:GetPlayers() do
        p:LoadCharacter()
    end
    self:SetState("Round", { Score = self.Score, Time = Config.RoundSeconds })

    local deadline = os.clock() + Config.RoundSeconds
    local winner
    while os.clock() < deadline do
        local red, blue = self:AlivePlayers("Red"), self:AlivePlayers("Blue")
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
        self.Score[winner] += 1
    end
    self:SetState("RoundOver", { Winner = winner, Score = self.Score })
    task.wait(4)
end

function RoundService:KnitStart()
    Players.CharacterAutoLoads = false -- rounds control spawning
    task.spawn(function()
        while true do
            repeat
                task.wait(1)
            until #Players:GetPlayers() >= Config.MinPlayers
            self:SetState("Intermission", { Time = Config.IntermissionSeconds })
            task.wait(Config.IntermissionSeconds)

            self.Score = { Red = 0, Blue = 0 }
            self:AssignTeams()
            repeat
                self:RunRound()
            until self.Score.Red >= Config.RoundsToWin
                or self.Score.Blue >= Config.RoundsToWin
                or #Players:GetPlayers() < Config.MinPlayers

            self:SetState("MatchOver", { Score = self.Score })
            task.wait(6)
        end
    end)
end

return RoundService
