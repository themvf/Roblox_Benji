-- Team Deathmatch rules that are pure arithmetic, shared by TDMService and its build gate
-- (tools/check_tdm.luau). The service owns the clock, spawning and kill attribution; this
-- decides what a kill is worth and when the match is over.
local TDM = {}

TDM.MODE = "TDM" -- RoundService broadcasts carry this as data.Mode

-- Does this death score? Only a kill by a player on the other team. A fall, a reset or a
-- team kill gives nobody a point.
function TDM.scores(victimTeam: string?, killerTeam: string?, killerIsVictim: boolean): boolean
    return not killerIsVictim
        and (victimTeam == "Red" or victimTeam == "Blue")
        and (killerTeam == "Red" or killerTeam == "Blue")
        and victimTeam ~= killerTeam
end

-- The winner, or nil while the match goes on: "Red", "Blue" or "Draw".
--   * the first team to reach the kill target wins outright
--   * at the time cap the higher score wins; equal is a draw
function TDM.winner(score: { Red: number, Blue: number }, killTarget: number, timeUp: boolean): string?
    local red, blue = score.Red or 0, score.Blue or 0
    if red >= killTarget and red > blue then
        return "Red"
    elseif blue >= killTarget and blue > red then
        return "Blue"
    end
    if timeUp then
        if red > blue then
            return "Red"
        elseif blue > red then
            return "Blue"
        end
        return "Draw"
    end
    return nil
end

return TDM
