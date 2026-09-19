-- Leaderboards: an OrderedDataStore per board, refreshed on a timer, shown on the lobby wall.
-- Boards: Rating (Convergence Rating composite), BestStreak, Wins, BountiesClaimed.
-- In Studio without API access the stores fail; we show a notice instead of crashing.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Progression = require(ReplicatedStorage.Shared.Progression)

local LeaderboardService = Knit.CreateService({
    Name = "LeaderboardService",
    Client = {
        Boards = Knit.CreateSignal(), -- (boards) { [name] = { {Name, Value, Rank} }, You = { [name] = rank } }
    },
})

local BOARDS = { "Rating", "BestStreak", "Wins", "BountiesClaimed" }
local REFRESH = 60

local stores = {}
local available = true

local function store(name)
    if not stores[name] then
        local ok, s = pcall(function()
            return DataStoreService:GetOrderedDataStore("Board_" .. name .. "_v1")
        end)
        if ok then
            stores[name] = s
        else
            available = false
        end
    end
    return stores[name]
end

local function statsOf(player)
    return {
        Matches = player:GetAttribute("Matches") or 0,
        Wins = player:GetAttribute("Wins") or 0,
        ObjectiveScore = player:GetAttribute("ObjectiveScore") or 0,
        MVPs = player:GetAttribute("MVPs") or 0,
        BountiesSurvived = player:GetAttribute("BountiesSurvived") or 0,
        BountiesClaimed = player:GetAttribute("BountiesClaimed") or 0,
        BestStreak = player:GetAttribute("BestStreak") or 0,
    }
end

function LeaderboardService:Submit(player)
    if not available or not player:GetAttribute("DataLoaded") then
        return
    end
    local s = statsOf(player)
    local values = {
        Rating = Progression.rating(s),
        BestStreak = s.BestStreak,
        Wins = s.Wins,
        BountiesClaimed = s.BountiesClaimed,
    }
    for name, value in values do
        local st = store(name)
        if st then
            pcall(function()
                st:SetAsync(tostring(player.UserId), value)
            end)
        end
    end
end

function LeaderboardService:Fetch()
    local boards = {}
    for _, name in BOARDS do
        local st = store(name)
        local rows = {}
        if st then
            local ok, pages = pcall(function()
                return st:GetSortedAsync(false, 10)
            end)
            if ok then
                for rank, item in pages:GetCurrentPage() do
                    local uid = tonumber(item.key)
                    local uname = uid and (Players:GetPlayerByUserId(uid) and Players:GetPlayerByUserId(uid).Name)
                    if not uname and uid then
                        local ok2, n = pcall(Players.GetNameFromUserIdAsync, Players, uid)
                        uname = ok2 and n or ("User " .. uid)
                    end
                    table.insert(rows, { Name = uname or item.key, Value = item.value, Rank = rank })
                end
            else
                available = false
            end
        end
        boards[name] = rows
    end
    boards.Available = available
    self.Client.Boards:FireAll(boards)
    self.Last = boards
    -- lobby wall
    local MapService = Knit.GetService("MapService")
    for name, entry in MapService.BoardLabels or {} do
        local lines = { entry.Title }
        if not available then
            table.insert(lines, "(enable Studio API access)")
        end
        for _, row in boards[name] or {} do
            table.insert(lines, ("%d. %s  %d"):format(row.Rank, row.Name, row.Value))
        end
        if available and #(boards[name] or {}) == 0 then
            table.insert(lines, "(no entries yet)")
        end
        entry.Label.Text = table.concat(lines, "\n")
    end
end

function LeaderboardService.Client:GetBoards(_player)
    return LeaderboardService.Last or { Available = available }
end

function LeaderboardService:KnitStart()
    task.spawn(function()
        while true do
            for _, p in Players:GetPlayers() do
                self:Submit(p)
            end
            self:Fetch()
            task.wait(REFRESH)
        end
    end)
    Players.PlayerRemoving:Connect(function(p)
        self:Submit(p)
    end)
end

return LeaderboardService
