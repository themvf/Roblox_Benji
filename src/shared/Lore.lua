-- Player-facing names from the Dark Matter lore bible (docs/design/lore/DARK_MATTER_LORE_BIBLE.md, section 12).
-- Display text only: team ids ("Red"/"Blue"), attribute keys, Config, Tuning and saved data never change,
-- and team colour (Palette) stays the primary team signal. Streak and bounty names live in Progression.
local Lore = {}

-- Plain colour names for now. The lore names are Red = "Forge", Blue = "Institute";
-- put them back here to bring them back on every screen at once.
Lore.Teams = { Red = "Red", Blue = "Blue" }

-- "Red" -> "Red"; anything unknown passes through unchanged
function Lore.teamName(team)
    return Lore.Teams[team] or tostring(team or "")
end

Lore.Charge = "Dark Charge" -- mutation energy
Lore.ChargeReady = "DARK CHARGE CRITICAL" -- replaces MUTATION READY
Lore.Bot = "Echo" -- bots are Echoes pulled in from other branches
Lore.Rating = "Coherence Rating" -- was Convergence Rating
Lore.Hub = "The Junction" -- the lobby

return Lore
