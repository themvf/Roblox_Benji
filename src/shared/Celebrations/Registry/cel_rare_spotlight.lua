-- Rare: motion + effects. A slow dance under a column of sparkles in the team colour.
return {
    Id = "cel_rare_spotlight",
    Tier = "Rare",
    Name = "Spotlight",
    Concept = "A slow dance in a spotlight of sparkles",
    Length = 6,
    Flashing = "low",
    Systems = {
        Motion = { Emote = "dance3", HoldPose = "idle" },
        Effects = { Type = "Sparkle", UseTeamColor = true, Count = 80 },
    },
}
