-- Mythical: all six systems. Fireworks, the whole team turns to watch, the camera orbits the MVP.
return {
    Id = "cel_myth_fireworks",
    Tier = "Mythical",
    Name = "Fireworks",
    Concept = "A whistle, fireworks over the podium, and the camera circles the MVP",
    Length = 8,
    Flashing = "high",
    Systems = {
        Motion = { Emote = "dance2", HoldPose = "idle" },
        Audio = { Sting = "TODO", VoiceLine = nil },
        Effects = { Type = "Fireworks", UseTeamColor = true, Count = 40, Bursts = 5 },
        Props = { Type = "Weapon", DespawnAt = 8 },
        Camera = { Type = "Orbit", Radius = 14, Height = 5, ReturnAt = 8 },
        Reactive = { Emote = "cheer" },
    },
}
