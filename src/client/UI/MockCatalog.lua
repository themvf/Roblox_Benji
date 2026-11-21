-- MockCatalog: made-up records that put every catalog state on screen at once.
--
-- For the gallery (UiGalleryController) and tools/check_ui.luau only. It proves layout: that
-- every access label, action, long name and empty slot draws and fits. It proves nothing about
-- ownership, rotation, lock-in or purchases, which need the real services.
--
-- Kit names and copy follow docs/design/kits/KIT_SELECTION_UI_SPEC.md; prices are placeholders.
local MockCatalog = {}

MockCatalog.Tabs = {
    { Id = "Kit", Label = "KITS" },
    { Id = "Pack", Label = "PACKS" },
    { Id = "Pass", Label = "PASSES" },
}

local DAY = 86400

function MockCatalog.items(now)
    return {
        {
            Id = "Neutron",
            Kind = "Kit",
            Title = "NEUTRON",
            Subtitle = "Defense",
            Summary = "Hold territory by resisting displacement.",
            Sections = {
                {
                    Heading = "PASSIVE - INERTIAL FRAME",
                    Body = "Resist enemy knockback while contesting or defending an objective.",
                },
                {
                    Heading = "TACTICAL - DEGENERATE ARMOR",
                    Body = "Brace against frontal attacks. You move slowly and cannot aim while active.",
                },
                { Heading = "COUNTER", Body = "Flank Neutron or attack after the armor releases." },
            },
            Access = "Starter",
            Selected = true,
            Action = "Equipped",
            Accent = "Energy",
        },
        {
            Id = "Neutrino",
            Kind = "Kit",
            Title = "NEUTRINO",
            Subtitle = "Infiltration",
            Summary = "Slip through a held line and arrive where nobody is looking.",
            Sections = {
                { Heading = "PASSIVE - WEAK INTERACTION", Body = "Footsteps are quieter while sprinting." },
                {
                    Heading = "TACTICAL - PHASE STEP",
                    Body = "Pass through one thin wall. You cannot fire for a moment after.",
                },
                { Heading = "COUNTER", Body = "Hold the far side of thin walls; the exit is loud." },
            },
            Access = "Starter",
            Selected = false,
            Action = "Equip",
            Accent = "Fly",
        },
        {
            Id = "Graviton",
            Kind = "Kit",
            Title = "GRAVITON",
            Subtitle = "Control",
            Summary = "Bend the fight toward a point you choose.",
            Sections = {
                { Heading = "PASSIVE - MASS", Body = "Fall slower while aiming." },
                { Heading = "TACTICAL - WELL", Body = "Pull enemies in a small area toward its centre for a moment." },
            },
            Access = "Trial",
            EndsAt = now + 2 * DAY + 4 * 3600,
            Selected = false,
            Action = "Equip",
            Accent = "Accent",
        },
        {
            Id = "Accretor",
            Kind = "Kit",
            Title = "ACCRETOR",
            Subtitle = "Sustain",
            Summary = "Grow stronger the longer you stay in the fight.",
            Sections = {
                { Heading = "PASSIVE - ACCRETION", Body = "Each elimination shortens your tactical cooldown." },
                { Heading = "COUNTER", Body = "Burst it down early; it has nothing until it gets going." },
            },
            Access = "Locked",
            Selected = false,
            Action = "Buy",
            Price = { Amount = 4500, Currency = "Credits" },
            Accent = "Good",
        },
        {
            -- the longest text every field allows: this is the overflow test
            Id = "LongNameKit",
            Kind = "Kit",
            Title = "MAGNETOHYDRODYNAMIC WARDEN",
            Subtitle = "Area denial and objective defense specialist",
            Summary = "A deliberately long summary that fills the whole line budget so wrapping and scrolling can be checked on a phone.",
            Sections = {
                {
                    Heading = "PASSIVE - A HEADING AT THE LENGTH LIMIT",
                    Body = "A body at the length limit, written only to prove that four full sections scroll inside the detail panel without pushing the action away.",
                },
                { Heading = "TACTICAL - SECOND SECTION", Body = "Second body." },
                { Heading = "LIMITATION", Body = "Third body." },
                { Heading = "COUNTER", Body = "Fourth body." },
            },
            Access = "Owned",
            Selected = false,
            Action = "Equip",
            Accent = "Warn",
        },
        {
            Id = "Pulsar",
            Kind = "Kit",
            Title = "PULSAR",
            Subtitle = "Skirmish",
            Summary = "High-tempo electric skirmisher built for close-quarters chains.",
            Access = "ComingSoon",
            Action = "None",
            Reason = "Arrives in a later season",
        },
        {
            Id = "BrokenKit",
            Kind = "Kit",
            Title = "QUASAR",
            Subtitle = "Burst",
            Summary = "Shown when the server cannot confirm what the player owns.",
            Access = "Unavailable",
            Action = "Unavailable",
            Reason = "Could not load ownership",
            Accent = "Danger",
        },
        {
            Id = "ExpiredKit",
            Kind = "Kit",
            Title = "MAGNETAR",
            Subtitle = "Disruption",
            Summary = "Shown the moment a free rotation ends.",
            Access = "Locked",
            Action = "TrialEnded",
            Reason = "The free rotation changed",
        },
        {
            Id = "StarterPack",
            Kind = "Pack",
            Title = "CONVERGENCE STARTER PACK",
            Subtitle = "One-time bundle",
            Summary = "Bonus Credits and a featured weapon skin.",
            Sections = {
                { Heading = "CONTAINS", Body = "2,000 Credits and one Rare weapon skin. Cosmetic and currency only." },
            },
            Access = "Locked",
            Action = "Buy",
            Price = { Amount = 399, Currency = "Robux" },
            Accent = "Accent",
        },
        {
            Id = "ForgeBundle",
            Kind = "Pack",
            Title = "FORGE UNION HEAVY BUNDLE",
            Subtitle = "Faction cosmetics",
            Summary = "Industrial molten weapon wraps, a celebration and a banner trim.",
            Access = "Locked",
            Action = "Pending",
            Accent = "Energy",
        },
        {
            Id = "InstituteBundle",
            Kind = "Pack",
            Title = "COHERENCE INSTITUTE PACK",
            Subtitle = "Faction cosmetics",
            Summary = "Cryo-circuit weapon skins, a holo-glyph trail and a celebration.",
            Access = "Owned",
            Action = "None",
            Accent = "Fly",
        },
        {
            Id = "DoubleXpPass",
            Kind = "Pass",
            Title = "2X COHERENCE XP",
            Subtitle = "Permanent progression pass",
            Summary = "Doubles lobby profile XP. No combat advantage.",
            Access = "Locked",
            Action = "Buy",
            Price = { Amount = 499, Currency = "Robux" },
            Accent = "Fly",
        },
        {
            Id = "VipJunctionPass",
            Kind = "Pass",
            Title = "VIP JUNCTION PASS",
            Subtitle = "Cosmetic prestige pass",
            Summary = "Gold lobby nameplate ring, extra celebration slots and a spawn aura.",
            Access = "Owned",
            Action = "None",
            Accent = "Warn",
        },
    }
end

-- The same kits as a pre-match lock-in sees them: Select / Locked in, no purchases.
function MockCatalog.lockIn(now)
    local items = {}
    for _, item in MockCatalog.items(now) do
        if item.Kind == "Kit" then
            local copy = table.clone(item)
            if copy.Action == "Equipped" then
                copy.Action = "LockedIn"
            elseif copy.Action == "Equip" then
                copy.Action = "Select"
            end
            table.insert(items, copy)
        end
    end
    return items
end

function MockCatalog.track(now)
    local rewards = { "Skin Ticket", "500 Credits", "Rare Weapon Skin", "Celebration", "Banner Trim" }
    local tiers = {}
    local level = 4
    for tier = 1, 12 do
        local reached = tier <= level
        tiers[tier] = {
            Tier = tier,
            Free = tier % 3 ~= 0 and {
                Title = rewards[tier % #rewards + 1],
                State = reached and (tier == level and "Claimable" or "Claimed") or "Locked",
            } or nil,
            Premium = { Title = rewards[(tier + 2) % #rewards + 1], State = "Premium" },
        }
    end
    return {
        Id = "Season1",
        Title = "SEASON 1: FIRST COLLAPSE",
        Subtitle = "Free and premium tracks",
        Level = level,
        Progress = 0.4,
        EndsAt = now + 23 * DAY,
        PremiumOwned = false,
        Action = "Buy",
        Price = { Amount = 799, Currency = "Robux" },
        Tiers = tiers,
    }
end

-- The lobby shell with everything switched on: six destinations (two of which may fold into
-- MORE), a wallet with two currencies, a running queue and two notification counts.
function MockCatalog.shell(now)
    return {
        Destinations = {
            { Id = "Loadout", Label = "LOADOUT" },
            { Id = "Shop", Label = "SHOP" },
            { Id = "Play", Label = "PLAY", Primary = true },
            { Id = "Pass", Label = "PASS" },
            { Id = "Customize", Label = "CUSTOMIZE", Fold = true },
            { Id = "Profile", Label = "PROFILE", Fold = true },
        },
        Profile = {
            Level = 12,
            Progress = 0.4,
            Currencies = { { Id = "Credits", Amount = 12450 }, { Id = "Tickets", Amount = 3 } },
        },
        Queue = { State = "Searching", Mode = "TEAM DEATHMATCH 5V5", Team = "BLUE", Since = now - 42 },
        Dots = { Shop = 2, Pass = 1, Profile = 12 },
    }
end

return MockCatalog
