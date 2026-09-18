-- Legendary: motion + audio + effects + props. Plants a flag in the team crest colour.
-- Audio is a placeholder until a sting is uploaded; the runtime skips it with a warning.
return {
    Id = "cel_leg_flag",
    Tier = "Legendary",
    Name = "Plant the Flag",
    Concept = "March in, plant a flag in the team colour, and salute it",
    Length = 8,
    Flashing = "low",
    Systems = {
        Motion = { Emote = "point", HoldPose = "idle" },
        Audio = { Sting = "TODO", VoiceLine = nil },
        Effects = { Type = "Sparkle", UseTeamColor = true, Count = 60 },
        Props = { Type = "Flag", UseTeamColor = true, DespawnAt = 8 },
    },
}
