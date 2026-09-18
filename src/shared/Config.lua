-- Tune the game here. Rivals-style: short rounds, first team to N wins.
return {
    IntermissionSeconds = 5, -- countdown after a queue fills, before round 1
    RoundSeconds = 90,
    RoundsToWin = 5,
    RespawnSeconds = 3, -- lobby respawn only; in a match you wait for the next round
    Teams = { "Red", "Blue" },
    Maps = { "Forest", "Snow", "Arena" }, -- one is picked at random per match (never the same twice in a row)
}
