-- Rare: motion + effects. Dance emote with a confetti burst in the player's team colour.
return {
    Id = "cel_rare_confetti",
    Tier = "Rare",
    Name = "Confetti Dance",
    Concept = "A dance under a shower of confetti in the winner's colour",
    Length = 6,
    Flashing = "low",
    Systems = {
        Motion = { Emote = "dance", HoldPose = "idle" },
        Effects = { Type = "Confetti", UseTeamColor = true, Count = 120 },
    },
}
