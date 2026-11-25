-- Preview catalog data for the scaffolded Junction Hub (Kits, Packs, Passes).
-- Keeps upcoming storefront sections cleanly separated from LobbyNavigationController
-- and clearly marks unshipped server features as COMING SOON (LFX-10).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)

local LobbyCatalog = {}

local titan = AlterEgos.get("Titan")

LobbyCatalog.Tabs = {
    { Id = "Kits", Label = "KITS" },
    { Id = "Packs", Label = "PACKS" },
    { Id = "Passes", Label = "PASSES" },
}

LobbyCatalog.Kits = {
    {
        Id = "Titan",
        Title = titan and titan.Name:upper() or "TITAN",
        Subtitle = "Vanguard  ·  Forge Union",
        Summary = titan and titan.Tagline or "Heavy exo-frame that mutates into Colossus.",
        Detail = "Ground Slam (E)  ·  Brace (F)  ·  Charge (C)",
        Badge = "STARTER",
        Accent = "Energy",
        Live = true,
    },
    {
        Id = "Kestrel",
        Title = "KESTREL",
        Subtitle = "Phase Runner  ·  Coherence Institute",
        Summary = "Out-of-sync infiltrator leaving decoy afterimages on mutation.",
        Detail = "Planned starter rotation  ·  Phase Blink / Wraith",
        Badge = "COMING SOON",
        Accent = "Fly",
        Live = false,
    },
    {
        Id = "Pulsar",
        Title = "PULSAR",
        Subtitle = "Flux Striker  ·  Cosmic",
        Summary = "High-tempo electric skirmisher built for close-quarters chains.",
        Detail = "Planned free rotation trial kit",
        Badge = "COMING SOON",
        Accent = "Accent",
        Live = false,
    },
    {
        Id = "BlackKnight",
        Title = "BLACK KNIGHT",
        Subtitle = "Heavy Bastion  ·  Armored",
        Summary = "Front-plated bruiser built for holding Convergence zones.",
        Detail = "Planned unlockable kit",
        Badge = "COMING SOON",
        Accent = "TextMuted",
        Live = false,
    },
    {
        Id = "RuneMage",
        Title = "RUNE MAGE",
        Subtitle = "Control  ·  Lattice",
        Summary = "Lattice researcher wielding entropy wards and glyph bolts.",
        Detail = "Planned unlockable kit",
        Badge = "COMING SOON",
        Accent = "Good",
        Live = false,
    },
    {
        Id = "Automaton",
        Title = "AUTOMATON",
        Subtitle = "Recon  ·  Utility",
        Summary = "Optical scout unit tuned for scanner pings and lane control.",
        Detail = "Planned unlockable kit",
        Badge = "COMING SOON",
        Accent = "Warn",
        Live = false,
    },
}

LobbyCatalog.Packs = {
    {
        Id = "StarterPack",
        Title = "CONVERGENCE STARTER PACK",
        Subtitle = "One-Time Bundle  ·  Store Foundation",
        Summary = "Introductory bundle with bonus Credits and a featured weapon skin.",
        Detail = "Pricing & receipt grant via StoreService (pending)",
        Badge = "COMING SOON",
        Accent = "Accent",
    },
    {
        Id = "ForgeBundle",
        Title = "FORGE UNION HEAVY BUNDLE",
        Subtitle = "Faction Cosmetics  ·  Cosmetic Only",
        Summary = "Industrial molten weapon wraps, celebration, and banner trim.",
        Detail = "No stat changes  ·  Creator Hub product pending",
        Badge = "COMING SOON",
        Accent = "Energy",
    },
    {
        Id = "InstituteBundle",
        Title = "COHERENCE INSTITUTE PACK",
        Subtitle = "Faction Cosmetics  ·  Cosmetic Only",
        Summary = "Cryo-circuit weapon skins, holo-glyph trail, and celebration.",
        Detail = "No stat changes  ·  Creator Hub product pending",
        Badge = "COMING SOON",
        Accent = "Fly",
    },
    {
        Id = "SkinCases",
        Title = "BRANCH SKIN CASES",
        Subtitle = "Cosmetic Cases  ·  Published Odds",
        Summary = "Entry and chase skin cases with duplicate protection and direct buy.",
        Detail = "Openable with Skin Tickets (pending)",
        Badge = "COMING SOON",
        Accent = "Good",
    },
}

LobbyCatalog.Passes = {
    {
        Id = "Season1Pass",
        Title = "SEASON 1 PASS: FIRST COLLAPSE",
        Subtitle = "Free & Premium Tracks  ·  XP Progression",
        Summary = "Earn weapon skins, celebrations, and Skin Tickets across 30+ tiers.",
        Detail = "Uses existing Progression XP curve (pending)",
        Badge = "COMING SOON",
        Accent = "Accent",
    },
    {
        Id = "StandardWeaponsPass",
        Title = "STANDARD WEAPONS PASS",
        Subtitle = "Lifetime Gamepass  ·  Current & Future",
        Summary = "Unlocks all Standard-tier weapons with one-time Credit refund.",
        Detail = "StoreService Gamepass authority pending",
        Badge = "COMING SOON",
        Accent = "Good",
    },
    {
        Id = "DoubleXpPass",
        Title = "2x COHERENCE XP & CREDITS",
        Subtitle = "Permanent Progression Pass",
        Summary = "Doubles lobby profile XP and match Credit earn rates.",
        Detail = "Progression rate only  ·  Zero combat advantage",
        Badge = "COMING SOON",
        Accent = "Fly",
    },
    {
        Id = "VipJunctionPass",
        Title = "VIP JUNCTION PASS",
        Subtitle = "Cosmetic Prestige Pass",
        Summary = "Gold lobby nameplate ring, extra celebration slots, and spawn aura.",
        Detail = "Cosmetic only  ·  StoreService pending",
        Badge = "COMING SOON",
        Accent = "Warn",
    },
}

return LobbyCatalog
