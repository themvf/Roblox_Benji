-- Team Deathmatch, 5v5: everyone respawns, every enemy kill is a point, and the first team to
-- the kill target wins -- or the higher score when the time cap runs out (equal is a draw).
--
-- It shares the pieces Duel already proved: RoundService's broadcast channel (the HUD shows the
-- Duel score bar for any non-Convergence round), MapService's team spawns (PlaceCharacter puts
-- every respawn on its team's side), damage code's LastHitBy for kill credit, and the same
-- end-of-match stats and celebration. RoundService.Busy is the one lock every mode takes, so
-- only one match runs at a time. The rules that are arithmetic live in Shared/TDM.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local TDM = require(ReplicatedStorage.Shared.TDM)

local TDMService = Knit.CreateService({ Name = "TDMService", Client = {} })

TDMService.Match = nil

local function present(match)
    local out = {}
    for _, p in match.Players do
        if p.Parent == Players and p:GetAttribute("InMatch") then
            table.insert(out, p)
        end
    end
    return out
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

-- Push the score and the time left; the HUD re-reads both from every Round broadcast.
function TDMService:Broadcast(match)
    local left = math.max(0, match.EndsAt - os.clock())
    Knit.GetService("RoundService")
        :Broadcast("Round", { Mode = TDM.MODE, Score = match.Score, Time = left, Target = match.Rules.KillTarget })
end

function TDMService:OnDeath(match, player, character)
    if not match.Running then
        return
    end
    local killerId = character:GetAttribute("LastHitBy")
    local killer = killerId and Players:GetPlayerByUserId(killerId)
    local victimTeam = player:GetAttribute("Team")
    local killerTeam = killer and killer:GetAttribute("InMatch") and killer:GetAttribute("Team")
    if TDM.scores(victimTeam, killerTeam, killer == player) then
        match.Score[killerTeam] += 1
        killer:SetAttribute("MatchKills", (killer:GetAttribute("MatchKills") or 0) + 1)
        self:Broadcast(match)
    end
    task.delay(match.Rules.RespawnSeconds, function()
        if match.Running and player.Parent and player:GetAttribute("InMatch") then
            player:LoadCharacter()
        end
    end)
end

-- Spawn protection: a ForceField for the first seconds of every life, so a team pinned at its
-- spawn is not fed kills as it respawns.
local function protect(character, seconds)
    if seconds <= 0 then
        return
    end
    local ff = Instance.new("ForceField")
    ff.Visible = true
    ff.Parent = character
    task.delay(seconds, function()
        if ff.Parent then
            ff:Destroy()
        end
    end)
end

function TDMService:WatchPlayer(match, player)
    local function onCharacter(character)
        protect(character, match.Rules.SpawnProtectSeconds)
        local hum = character:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                self:OnDeath(match, player, character)
            end)
        end
    end
    table.insert(match.Connections, player.CharacterAdded:Connect(onCharacter))
end

-- players: array of Player, the first `teamSize` are Red and the rest Blue (QueueService and
-- the map vote hand them over in that order, as for Duel).
function TDMService:StartMatch(players, teamSize, mapName)
    local RoundService = Knit.GetService("RoundService")
    if RoundService.Busy then
        return false
    end
    RoundService.Busy = true
    local rules = Config.GetTDM()
    local match = {
        Players = players,
        Score = { Red = 0, Blue = 0 },
        Mode = TDM.MODE,
        Rules = rules,
        Connections = {},
        Running = false,
    }
    self.Match = match

    for i, player in players do
        player:SetAttribute("InMatch", true)
        player:SetAttribute("Team", i <= teamSize and "Red" or "Blue")
        player:SetAttribute("MatchKills", 0)
        self:WatchPlayer(match, player)
    end

    task.spawn(function()
        local MapService = Knit.GetService("MapService")
        local map = mapName or Config.TDMMaps[1]
        -- load first, as Convergence does: the intermission's vista camera reads the loaded map
        if not MapService:Load(map) then
            warn("[TDM] could not load " .. tostring(map) .. "; aborting")
            self:Finish(match, nil, true)
            return
        end
        RoundService:Broadcast(
            "Intermission",
            { Time = Config.IntermissionSeconds, Mode = TDM.MODE, Map = map, Vista = MapService.Vista }
        )
        task.wait(Config.IntermissionSeconds)

        match.Running = true
        match.EndsAt = os.clock() + rules.MaxSeconds
        for _, p in present(match) do
            p:LoadCharacter()
        end
        self:Broadcast(match)

        local winner, aborted
        while true do
            if teamCount(match, "Red") == 0 or teamCount(match, "Blue") == 0 then
                aborted = true -- a whole team left
                break
            end
            winner = TDM.winner(match.Score, rules.KillTarget, os.clock() >= match.EndsAt)
            if winner then
                break
            end
            task.wait(0.25)
        end
        match.Running = false
        self:Finish(match, winner, aborted)
    end)
    return true
end

function TDMService:Finish(match, winner, aborted)
    local RoundService = Knit.GetService("RoundService")
    for _, c in match.Connections do
        c:Disconnect()
    end
    RoundService:Broadcast(
        "MatchOver",
        { Score = match.Score, Mode = TDM.MODE, Winner = winner, Aborted = aborted == true }
    )

    if not aborted then
        for _, p in present(match) do
            p:SetAttribute("Matches", (p:GetAttribute("Matches") or 0) + 1)
            p:SetAttribute("Kills", (p:GetAttribute("Kills") or 0) + (p:GetAttribute("MatchKills") or 0))
        end
    end
    if not aborted and (winner == "Red" or winner == "Blue") then
        local winners, losers = {}, {}
        for _, p in present(match) do
            if p:GetAttribute("Team") == winner then
                table.insert(winners, p)
            else
                table.insert(losers, p)
            end
        end
        -- MVP order: most kills first
        table.sort(winners, function(a, b)
            local ka, kb = a:GetAttribute("MatchKills") or 0, b:GetAttribute("MatchKills") or 0
            if ka ~= kb then
                return ka > kb
            end
            return a.UserId < b.UserId
        end)
        for _, p in winners do
            p:SetAttribute("Wins", (p:GetAttribute("Wins") or 0) + 1)
        end
        Knit.GetService("CelebrationService"):Run(winners, losers)
    else
        task.wait(4) -- a draw or an abort: the result line stays up briefly, no podium
    end

    for _, p in present(match) do
        RoundService:SendToLobby(p)
    end
    self.Match = nil
    RoundService.Busy = false
    RoundService:Broadcast("Lobby", {})
end

return TDMService
