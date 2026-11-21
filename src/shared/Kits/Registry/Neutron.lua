-- The worked example for the kit workflow (kit-from-prompt skill). Design only: no server
-- handler exists yet, the price is pending, and none of these numbers has been played.
-- Design record: docs/design/kits/neutron/KIT_RECORD.md
return {
    Id = "Neutron",
    Name = "NEUTRON",
    Role = "Defense",
    Fantasy = "Hold territory by resisting displacement.",
    Decision = "When to plant on a point and brace, and when to give ground before you are flanked.",
    Status = "Design",
    Access = "Purchasable",
    RotationEligible = true,
    Price = nil, -- pending: the store and Credit prices are not decided (store-foundation packet)
    Passive = {
        Name = "INERTIAL FRAME",
        Text = "Resist enemy knockback while standing in an objective zone.",
        Handler = "ObjectiveKnockbackResist",
        Tuning = {
            KnockbackResist = { Default = 0.5, Min = 0, Max = 0.7, Unit = "fraction" },
        },
    },
    Tactical = {
        Name = "DEGENERATE ARMOR",
        Text = "Brace against frontal attacks. You move slowly and cannot aim down sights while active.",
        Handler = "FrontalBrace",
        TouchLabel = "BRACE",
        Cooldown = { Default = 12, Min = 6, Max = 30, Unit = "s" },
        Tuning = {
            Duration = { Default = 3, Min = 1, Max = 5, Unit = "s" },
            FrontalResist = { Default = 0.5, Min = 0.2, Max = 0.7, Unit = "fraction" },
            SpeedMultiplier = { Default = 0.6, Min = 0.4, Max = 1, Unit = "multiplier" },
        },
    },
    Cost = "Slow and unable to aim down sights for the whole brace; the back and sides take full damage.",
    Counter = "Flank Neutron or wait out the brace; it cannot turn fast enough to cover two angles.",
    Stacking = "Two Neutrons brace separately. A new brace refreshes the duration rather than adding to it.",
    Look = { Package = nil, Note = "No art yet. Reads as the default character until a kit look is approved." },
}
