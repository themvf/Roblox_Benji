-- Design record: docs/design/kits/blackknight/KIT_RECORD.md
-- Design only: no server handler exists yet, the price is pending, and none of these
-- numbers has been played. No melee here: the hammer comes later as its own unlockable weapon.
return {
    Id = "BlackKnight",
    Name = "BLACK KNIGHT",
    Role = "Offense",
    Fantasy = "A walking wall that breaks the enemy line.",
    Decision = "When to spend the charge to break a held point, knowing a miss leaves you exposed.",
    Status = "Design",
    Access = "Purchasable",
    RotationEligible = true,
    Price = nil, -- pending until the store's Credit prices are decided
    Passive = {
        Name = "HEAVY PLATE",
        Text = "Enemy knockback from the front moves you half as far.",
        Handler = "FrontalKnockbackResist",
        Tuning = {
            KnockbackResist = { Default = 0.5, Min = 0, Max = 0.7, Unit = "fraction" },
            FrontDot = { Default = 0.3, Min = 0, Max = 0.9, Unit = "dot product" },
        },
    },
    Tactical = {
        Name = "BREACH",
        Text = "Charge a short way forward. The first enemy hit is shoved back and slowed. You cannot fire during it.",
        Handler = "ForwardBash",
        TouchLabel = "BREACH",
        Cooldown = { Default = 12, Min = 6, Max = 30, Unit = "s" },
        Tuning = {
            ChargeSpeed = { Default = 55, Min = 40, Max = 70, Unit = "studs/s" },
            ChargeDuration = { Default = 0.45, Min = 0.3, Max = 0.8, Unit = "s" },
            HitRadius = { Default = 5, Min = 3, Max = 7, Unit = "studs" },
            Push = { Default = 40, Min = 20, Max = 60, Unit = "studs/s" },
            SlowDuration = { Default = 0.6, Min = 0.2, Max = 1, Unit = "s" },
            SlowSpeedMultiplier = { Default = 0.5, Min = 0.3, Max = 1, Unit = "multiplier" },
            Recovery = { Default = 0.5, Min = 0.3, Max = 1, Unit = "s" },
        },
    },
    Cost = "No firing during the charge or for half a second after; a miss leaves you close and exposed.",
    Counter = "Sidestep the charge and punish the recovery, or shoot from the side or back, where the plate does not help.",
    Stacking = "Each knight charges on its own. A target already slowed is not slowed further; the slow restarts.",
    Look = {
        Package = "assets/kit-looks/BlackKnight",
        Note = "Approved review sheet (2026-11-18): ten Tripo pieces on R15, 19,001 triangles. Not in game yet.",
    },
}
