-- Alter Ego and Mutation System v1 data. Numbers from the spec; all are placeholders for balance.
local AlterEgos = {}

AlterEgos.DEFAULT = "Titan"

AlterEgos.Energy = {
    Kill = 20,
    Assist = 10,
    Capture = 25,
    DefenseTick = 5, -- per DefenseTickSeconds inside an owned zone
    DefenseTickSeconds = 10,
    BountyKill = 30,
    Support = 10, -- reserved: no support actions exist yet
    ContestedCapture = 15, -- capture of a zone that was contested within ContestedWindow
    ContestedWindow = 10,
    Cap = 100,
}

AlterEgos.Mutation = {
    DurationSeconds = 25,
    TransformSeconds = 1.2,
    ActivateKey = "Q",
}

AlterEgos.List = {
    Titan = {
        Name = "Titan",
        Tagline = "Hold the line, then become the line.",
        Mutant = "Colossus",
        Announce = "TITAN HAS MUTATED",
        -- visual read: Titan is broad (shoulder plates), Colossus is 1.35x with a molten core
        Scale = 1.35,
        Color = Color3.fromRGB(255, 120, 40),
        Abilities = {
            GroundSlam = {
                Key = "E",
                Cooldown = 7,
                Radius = 14,
                Damage = 35,
                Knockback = 55, -- studs/s away from the slam, plus lift
                Lift = 30,
            },
            Brace = {
                Key = "F",
                Cooldown = 8,
                Duration = 3,
                FrontalResistance = 0.6, -- 60% less damage from the front
                MoveSpeedMultiplier = 0.6,
                FrontDot = 0.3, -- attacker direction dot look >= this counts as frontal
            },
            Charge = {
                Key = "C",
                Cooldown = 6,
                Duration = 0.6,
                Speed = 70, -- studs/s
                SteerDegreesPerSecond = 90, -- limited steering
                HitRadius = 6,
                Damage = 20,
                Push = 45,
            },
        },
    },
}

AlterEgos.ABILITY_ORDER = { "GroundSlam", "Brace", "Charge" }

function AlterEgos.get(id)
    return AlterEgos.List[id]
end

return AlterEgos
