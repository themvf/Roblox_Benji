-- Build gate: Team Deathmatch 5v5.
--
--   * the rules (Shared/TDM): what scores, when the match ends, draws at the cap
--   * the settings (Config.GetTDM): Tuning overrides apply, junk and out-of-range values
--     cannot start a 0-kill or 0-second match, the minimum team never exceeds the full one
--   * the wiring: the lobby has a TDM pad, the queue starts TDMService for it, the map vote
--     draws from TDMMaps, and the service takes the shared RoundService lock
--
-- What it cannot check is a live match: respawns, spawn protection and the HUD need Studio.
--
--     lune run tools/check_tdm.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local Config = require("../src/shared/Config")
local TDM = require("../src/shared/TDM")

local passed, failed = 0, 0
local function check(what, cond, detail)
    if cond then
        passed += 1
        print("PASS  " .. what)
    else
        failed += 1
        print("FAIL  " .. what .. (detail and ("\n        " .. tostring(detail)) or ""))
    end
end

-- ===== rules =====
check("an enemy kill scores", TDM.scores("Red", "Blue", false))
check("a team kill does not score", not TDM.scores("Red", "Red", false))
check("a self kill does not score", not TDM.scores("Red", "Red", true))
check("a death with no killer does not score", not TDM.scores("Red", nil, false))
check("a lobby player cannot score", not TDM.scores("Red", "Lobby", false))

check("no winner mid-match", TDM.winner({ Red = 10, Blue = 9 }, 50, false) == nil)
check("first to the target wins", TDM.winner({ Red = 50, Blue = 49 }, 50, false) == "Red")
check("blue can win too", TDM.winner({ Red = 3, Blue = 50 }, 50, false) == "Blue")
check("at the cap, more kills wins", TDM.winner({ Red = 12, Blue = 20 }, 50, true) == "Blue")
check("at the cap, equal kills is a draw", TDM.winner({ Red = 20, Blue = 20 }, 50, true) == "Draw")
check("at the cap with no kills is a draw", TDM.winner({ Red = 0, Blue = 0 }, 50, true) == "Draw")

-- ===== settings =====
local defaults = Config.GetTDM()
check("default is 5v5", defaults.TeamSize == 5)
check("default target is 50 kills", defaults.KillTarget == 50)
check("default cap is 10 minutes", defaults.MaxSeconds == 600)
check("minimum team defaults below full", defaults.MinTeamSize < defaults.TeamSize)

local function withTuning(attrs)
    local fake = {
        GetAttribute = function(_, key)
            return attrs[key]
        end,
    }
    Config.SetOverrideSource(fake)
    local out = Config.GetTDM()
    Config.SetOverrideSource(nil)
    return out
end

local tuned = withTuning({ TDM_KillTarget = 30, TDM_TeamSize = 4 })
check("Tuning overrides the kill target", tuned.KillTarget == 30)
check("Tuning overrides the team size", tuned.TeamSize == 4)

local junk = withTuning({
    TDM_KillTarget = 0,
    TDM_MaxSeconds = -5,
    TDM_RespawnSeconds = 0 / 0,
    TDM_TeamSize = "five",
    TDM_MinTeamSize = 99,
})
check("a 0-kill target is clamped up", junk.KillTarget >= 1, junk.KillTarget)
check("a negative cap is clamped up", junk.MaxSeconds >= 30, junk.MaxSeconds)
check("NaN respawn falls back to the default", junk.RespawnSeconds == Config.TDM.RespawnSeconds, junk.RespawnSeconds)
check("a non-number team size falls back", junk.TeamSize == 5, junk.TeamSize)
check("minimum team never exceeds the full team", junk.MinTeamSize <= junk.TeamSize, junk.MinTeamSize)

local fractional = withTuning({ TDM_KillTarget = 12.7, TDM_TeamSize = 3.9 })
check("counts are whole numbers", fractional.KillTarget == 12 and fractional.TeamSize == 3)

check("TDM plays Snow Fortress", table.find(Config.TDMMaps, "SnowFortress") ~= nil)

-- ===== wiring =====
local lobby = require("../src/shared/Maps/Lobby")
local tdmPads = {}
for _, pad in lobby.Pads do
    if pad.kind == "TDM" then
        table.insert(tdmPads, pad)
    end
end
check("the lobby has exactly one TDM pad", #tdmPads == 1, #tdmPads)
check("Duel 1v1 and 2v2 pads remain", (function()
    local sizes = {}
    for _, pad in lobby.Pads do
        if (pad.kind or "Duel") == "Duel" then
            sizes[pad.teamSize] = true
        end
    end
    return sizes[1] and sizes[2]
end)())

local function source(path)
    return fs.readFile(path)
end
local queue = source("src/server/Services/QueueService.lua")
check(
    "the queue starts TDMService for a TDM pad",
    queue:find('kind == "TDM"', 1, true) and queue:find('GetService("TDMService"):StartMatch', 1, true)
)
check("the queue gives TDM a fill wait", queue:find("Config.GetTDM().FillWaitSeconds", 1, true) ~= nil)
local vote = source("src/server/Services/MapVoteService.lua")
check("the map vote draws TDM maps from TDMMaps", vote:find("Config.TDMMaps", 1, true) ~= nil)
local service = source("src/server/Services/TDMService.lua")
check("TDMService takes the shared match lock", service:find("RoundService.Busy = true", 1, true) ~= nil)
check("TDMService releases the lock", service:find("RoundService.Busy = false", 1, true) ~= nil)
check("TDMService uses the shared rules", service:find("TDM.winner(", 1, true) ~= nil)

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    process.exit(1)
end
