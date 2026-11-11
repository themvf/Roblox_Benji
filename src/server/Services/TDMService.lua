-- Public five-versus-five Team Deathmatch on approved TDM maps. The queue owns
-- admission; this service owns scoring, respawns, the clock, and cleanup.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local TDMRules = require(ReplicatedStorage.Shared.TDMRules)

local TDMService = Knit.CreateService({ Name = "TDMService" })
TDMService.Busy = false
TDMService.Match = nil

local MODE = "Team Deathmatch"

local function present(match)
    local result = {}
    for _, player in match.Players do
        if player.Parent == Players then
            table.insert(result, player)
        end
    end
    return result
end

-- A public match ends when a side walks out. A training match has one human and bots on
-- both sides, so an empty side is its normal state; it ends only when the player leaves.
local function abandoned(match)
    if match.Solo then
        return #present(match) == 0
    end
    local red, blue = 0, 0
    for _, player in present(match) do
        if player:GetAttribute("Team") == "Red" then
            red += 1
        elseif player:GetAttribute("Team") == "Blue" then
            blue += 1
        end
    end
    return red == 0 or blue == 0
end

function TDMService:Broadcast(match, state, timeLeft, extra)
    local data = {
        Mode = MODE,
        Map = match.MapDisplay,
        Score = table.clone(match.Score),
        Time = timeLeft,
        Target = match.Rules.ScoreToWin,
    }
    for key, value in extra or {} do
        data[key] = value
    end
    Knit.GetService("RoundService"):Broadcast(state, data)
end

function TDMService:Credit(match, team)
    match.Score[team] += 1
    local remaining = math.max(0, match.Deadline - os.clock())
    self:Broadcast(match, match.Overtime and "Overtime" or "Round", remaining)
end

-- A bot died: a player's recent hit scores for that player, a bot's for the bot's team.
function TDMService:OnBotKilled(match, killerId, victimTeam)
    if not match.Running or match.Finished or type(killerId) ~= "number" then
        return
    end
    local killerTeam = victimTeam == "Red" and "Blue" or "Red"
    if killerId > 0 then
        local killer = Players:GetPlayerByUserId(killerId)
        if not killer or not table.find(match.Players, killer) or killer:GetAttribute("Team") ~= killerTeam then
            return
        end
        killer:SetAttribute("MatchKills", (killer:GetAttribute("MatchKills") or 0) + 1)
    end
    self:Credit(match, killerTeam)
end

function TDMService:OnDeath(match, victim, character)
    if not match.Running or match.Finished then
        return
    end
    local victimTeam = victim:GetAttribute("Team")
    local killerId = character:GetAttribute("LastHitBy")
    local hitAt = character:GetAttribute("LastHitAt")
    local killer = type(killerId) == "number" and Players:GetPlayerByUserId(killerId) or nil
    local killerTeam = killer and killer:GetAttribute("Team")
    if
        killer
        and killer ~= victim
        and table.find(match.Players, killer)
        and killer:GetAttribute("InMatch")
        and (killerTeam == "Red" or killerTeam == "Blue")
        and killerTeam ~= victimTeam
        and type(hitAt) == "number"
        and os.clock() - hitAt <= match.Rules.RecentHitSeconds
    then
        match.Score[killerTeam] += 1
        killer:SetAttribute("MatchKills", (killer:GetAttribute("MatchKills") or 0) + 1)
        local remaining = math.max(0, match.Deadline - os.clock())
        self:Broadcast(match, match.Overtime and "Overtime" or "Round", remaining)
    elseif
        type(killerId) == "number"
        and killerId < 0
        and (victimTeam == "Red" or victimTeam == "Blue")
        and type(hitAt) == "number"
        and os.clock() - hitAt <= match.Rules.RecentHitSeconds
    then
        self:Credit(match, victimTeam == "Red" and "Blue" or "Red")
    end

    task.delay(match.Rules.RespawnSeconds, function()
        if match.Running and not match.Finished and victim.Parent == Players and victim:GetAttribute("InMatch") then
            victim:LoadCharacter()
        end
    end)
end

function TDMService:WatchCharacter(match, player, character)
    if not match.Running or match.Finished then
        return
    end
    local shield = Instance.new("ForceField")
    shield.Name = "TDMSpawnProtection"
    shield.Visible = true
    shield.Parent = character
    task.delay(match.Rules.SpawnProtectSeconds, function()
        if shield.Parent then
            shield:Destroy()
        end
    end)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        table.insert(
            match.Connections,
            humanoid.Died:Connect(function()
                self:OnDeath(match, player, character)
            end)
        )
    end
end

function TDMService:Finish(match, winner, aborted)
    if match.Finished then
        return
    end
    match.Finished = true
    match.Running = false
    self:Broadcast(match, "MatchOver", nil, { Winner = winner, Draw = not winner and not aborted, Aborted = aborted })
    if match.Solo then
        Knit.GetService("BotService"):Stop()
    end
    for _, connection in match.Connections do
        connection:Disconnect()
    end
    if not aborted and not match.Solo then -- training against bots does not count toward stats
        for _, player in present(match) do
            player:SetAttribute("Matches", (player:GetAttribute("Matches") or 0) + 1)
            player:SetAttribute("Kills", (player:GetAttribute("Kills") or 0) + (player:GetAttribute("MatchKills") or 0))
            if winner and player:GetAttribute("Team") == winner then
                player:SetAttribute("Wins", (player:GetAttribute("Wins") or 0) + 1)
            end
        end
    end
    task.wait(aborted and 1 or 4)
    local rounds = Knit.GetService("RoundService")
    for _, player in present(match) do
        rounds:SendToLobby(player)
    end
    self.Match = nil
    self.Busy = false
    rounds.Busy = false
    rounds:Broadcast("Lobby", {})
end

function TDMService:Run(match, mapName)
    local maps = Knit.GetService("MapService")
    if not maps:Load(mapName) then
        self:Finish(match, nil, true)
        return
    end
    local layout = maps:GetLayout(mapName)
    match.MapDisplay = layout and layout.DisplayName or mapName
    self:Broadcast(match, "Intermission", Config.IntermissionSeconds)
    task.wait(Config.IntermissionSeconds)
    if abandoned(match) then
        self:Finish(match, nil, true)
        return
    end

    match.Deadline = os.clock() + match.Rules.RegulationSeconds
    match.Running = true
    for _, player in present(match) do
        player:LoadCharacter()
    end
    if match.Solo then
        local humans = { Red = 0, Blue = 0 }
        for _, player in present(match) do
            humans[player:GetAttribute("Team")] += 1
        end
        Knit.GetService("BotService")
            :Start(Config.TrainingBots(Config.GetTraining().TeamSize, humans), match.Rules.RespawnSeconds, function()
                return {} -- no zones: bots hunt the nearest enemy
            end, function(killerId, victimTeam)
                self:OnBotKilled(match, killerId, victimTeam)
            end)
    end
    self:Broadcast(match, "Round", match.Rules.RegulationSeconds)
    while os.clock() < match.Deadline do
        if abandoned(match) then
            self:Finish(match, nil, true)
            return
        end
        local action, winner = TDMRules.decision(match.Score, match.Rules.ScoreToWin, false, false)
        if action == "win" then
            self:Finish(match, winner, false)
            return
        end
        task.wait(0.25)
    end

    local action, winner = TDMRules.decision(match.Score, match.Rules.ScoreToWin, true, false)
    if action == "win" then
        self:Finish(match, winner, false)
        return
    end
    match.Overtime = true
    match.Deadline = os.clock() + match.Rules.OvertimeSeconds
    self:Broadcast(match, "Overtime", match.Rules.OvertimeSeconds)
    while os.clock() < match.Deadline do
        if abandoned(match) then
            self:Finish(match, nil, true)
            return
        end
        task.wait(0.25)
    end
    local _, overtimeWinner = TDMRules.decision(match.Score, match.Rules.ScoreToWin, true, true)
    self:Finish(match, overtimeWinner, false)
end

-- Public: ten players, the first five Red. `solo` is training: one player on Red, and
-- bots fill both teams to Config.Training.TeamSize once the round starts.
function TDMService:StartMatch(players, mapName, solo)
    local rounds = Knit.GetService("RoundService")
    local count = solo and 1 or 10
    if self.Busy or rounds.Busy or #players ~= count or not table.find(Config.TDMMaps, mapName) then
        return false
    end
    local seen = {}
    for _, player in players do
        if player.Parent ~= Players or seen[player] then
            return false
        end
        seen[player] = true
    end
    self.Busy = true
    rounds.Busy = true
    local match = {
        Players = players,
        Score = { Red = 0, Blue = 0 },
        Rules = Config.GetTDM(),
        Connections = {},
        Running = false,
        Finished = false,
        Overtime = false,
        Solo = solo == true,
    }
    self.Match = match
    for index, player in players do
        player:SetAttribute("InMatch", true)
        player:SetAttribute("Team", index <= 5 and "Red" or "Blue")
        player:SetAttribute("MatchKills", 0)
        table.insert(
            match.Connections,
            player.CharacterAdded:Connect(function(character)
                self:WatchCharacter(match, player, character)
            end)
        )
    end
    task.spawn(function()
        local ok, failure = xpcall(function()
            self:Run(match, mapName)
        end, debug.traceback)
        if not ok then
            warn("[TDM] match failed: " .. tostring(failure))
            self:Finish(match, nil, true)
        end
    end)
    return true
end

return TDMService
