-- Common: motion only. Uses Roblox's built-in wave emote, so it works with no uploads.
return {
    Id = "cel_common_wave",
    Tier = "Common",
    Name = "Wave",
    Concept = "A friendly wave to the crowd, then a hold with the face to camera",
    Length = 4,
    Flashing = "none",
    Systems = {
        Motion = { Emote = "wave", HoldPose = "idle" },
    },
}
