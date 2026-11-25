-- CatalogItem: the one record every sellable or selectable thing is shown from.
--
-- A kit, a pack, a pass, a skin and a celebration are all drawn by the same card, detail panel
-- and primary action (client/UI/Components, client/UI/CatalogScreen). What differs is this data.
-- The server builds the records, because only it knows what a player owns; the client draws them
-- and never works out ownership, price or availability for itself.
--
--   {
--     Id = "Neutron",                 unique within its Kind
--     Kind = "Kit",                   which tab it belongs to (CatalogItem.Kinds)
--     Title = "NEUTRON",
--     Subtitle = "Defense",           role or type line
--     Summary = "Hold territory by resisting displacement.",
--     Sections = { { Heading = "PASSIVE - INERTIAL FRAME", Body = "..." } },   up to four
--     Access = "Starter",             CatalogItem.Access: the one access label on the card
--     Selected = true,                the equipped / locked-in marker, separate from Access
--     Action = "Equipped",            CatalogItem.Actions: the primary button for this player
--     Price = { Amount = 800, Currency = "Credits" },   needed for Action = "Buy"
--     EndsAt = 1790000000,            server time; needed for Access = "Trial"
--     Reason = "Reach level 5",       why it cannot be used, shown beside a disabled action
--     Accent = "Energy",              a Theme.Color token name
--   }
--
-- A season track (CatalogItem.validateTrack) is the one screen that is not a list of cards.
-- tools/check_ui.luau runs both validators over every catalog in the repo.
local CatalogItem = {}

CatalogItem.Kinds = { "Kit", "Pack", "Pass", "Weapon", "Skin", "Celebration", "Boost" }

-- Access: text shown on the card. `Usable` decides whether the item can be selected.
CatalogItem.Access = {
    Starter = { Label = "STARTER", Usable = true, Tone = "Good" },
    Trial = { Label = "FREE THIS ROTATION", Usable = true, Tone = "Fly" },
    Owned = { Label = "OWNED", Usable = true, Tone = "Good" },
    Locked = { Label = "LOCKED", Usable = false, Tone = "TextMuted" },
    Unavailable = { Label = "UNAVAILABLE", Usable = false, Tone = "Danger" },
    ComingSoon = { Label = "COMING SOON", Usable = false, Tone = "TextMuted" },
}

-- Actions: the primary button. `Enabled = false` is a state readout, not a button to press.
-- `Confirm` actions open a confirmation first; nothing is bought from a single tap.
CatalogItem.Actions = {
    Equip = { Label = "EQUIP", Enabled = true },
    Equipped = { Label = "EQUIPPED", Enabled = false },
    Select = { Label = "SELECT", Enabled = true },
    LockedIn = { Label = "LOCKED IN", Enabled = false },
    Buy = { Label = "BUY", Enabled = true, Confirm = true },
    Claim = { Label = "CLAIM", Enabled = true },
    Pending = { Label = "CHECKING PURCHASE...", Enabled = false },
    TrialEnded = { Label = "TRIAL ENDED", Enabled = false },
    MatchLocked = { Label = "MATCH LOCKED", Enabled = false },
    Unavailable = { Label = "UNAVAILABLE", Enabled = false },
    None = { Label = "", Enabled = false },
}

CatalogItem.Currencies = { "Credits", "Robux", "Tickets" }

-- Theme.Color tokens a record may name. check_ui confirms each exists in client/UI/Theme.
CatalogItem.Accents = { "Accent", "Energy", "Fly", "Good", "Warn", "Danger", "TextMuted" }

-- Longest text each field may carry. The card and detail panel are sized for these at the
-- phone text floor; longer copy would be cut off, so it fails the gate instead.
CatalogItem.Limits = {
    Title = 28,
    Subtitle = 48,
    Summary = 120,
    Heading = 40,
    Body = 160,
    Reason = 60,
    Sections = 4,
}

-- Reward states on a season track.
CatalogItem.RewardStates = {
    Claimed = { Label = "CLAIMED" },
    Claimable = { Label = "CLAIM" },
    Locked = { Label = "LOCKED" },
    Premium = { Label = "PREMIUM" },
}

local function text(errors, where, name, value, limit, optional)
    if value == nil and optional then
        return
    end
    if type(value) ~= "string" or value == "" then
        table.insert(errors, ("%s: %s must be text"):format(where, name))
    elseif #value > limit then
        table.insert(errors, ("%s: %s is %d characters, limit %d"):format(where, name, #value, limit))
    end
end

-- Returns a list of problems; an empty list means the record can be drawn.
function CatalogItem.validate(item)
    local errors = {}
    if type(item) ~= "table" then
        return { "item is not a table" }
    end
    local where = tostring(item.Id or "?")
    local limits = CatalogItem.Limits
    text(errors, where, "Id", item.Id, 40)
    if not table.find(CatalogItem.Kinds, item.Kind) then
        table.insert(errors, where .. ": Kind is not one of CatalogItem.Kinds")
    end
    text(errors, where, "Title", item.Title, limits.Title)
    text(errors, where, "Subtitle", item.Subtitle, limits.Subtitle)
    text(errors, where, "Summary", item.Summary, limits.Summary)
    text(errors, where, "Reason", item.Reason, limits.Reason, true)

    local sections = item.Sections or {}
    if type(sections) ~= "table" or #sections > limits.Sections then
        table.insert(errors, ("%s: Sections must be a list of at most %d"):format(where, limits.Sections))
    else
        for index, section in sections do
            local at = ("%s section %d"):format(where, index)
            if type(section) ~= "table" then
                table.insert(errors, at .. ": not a table")
            else
                text(errors, at, "Heading", section.Heading, limits.Heading)
                text(errors, at, "Body", section.Body, limits.Body)
            end
        end
    end

    local access = CatalogItem.Access[item.Access]
    if not access then
        table.insert(errors, where .. ": Access is not one of CatalogItem.Access")
    end
    local action = CatalogItem.Actions[item.Action]
    if not action then
        table.insert(errors, where .. ": Action is not one of CatalogItem.Actions")
    end
    if item.Accent ~= nil and not table.find(CatalogItem.Accents, item.Accent) then
        table.insert(errors, where .. ": Accent is not one of CatalogItem.Accents")
    end
    if item.Selected ~= nil and type(item.Selected) ~= "boolean" then
        table.insert(errors, where .. ": Selected must be true or false")
    end

    -- The states have to agree with each other, or the card says two things at once.
    if access and action then
        local usable = access.Usable
        if item.Selected and not usable then
            table.insert(errors, where .. ": selected but not usable")
        end
        if (item.Action == "Equip" or item.Action == "Select") and not usable then
            table.insert(errors, where .. ": can be equipped but is not usable")
        end
        if (item.Action == "Equipped" or item.Action == "LockedIn") and not item.Selected then
            table.insert(errors, where .. ": action says selected, Selected does not")
        end
        if (item.Action == "Equip" or item.Action == "Select") and item.Selected then
            table.insert(errors, where .. ": already selected but offers to select")
        end
        if item.Action == "Buy" and item.Access ~= "Locked" then
            table.insert(errors, where .. ": Buy is only for a Locked item")
        end
    end
    if item.Action == "Buy" then
        local price = item.Price
        if type(price) ~= "table" or type(price.Amount) ~= "number" or price.Amount <= 0 then
            table.insert(errors, where .. ": Buy needs Price.Amount")
        elseif price.Amount % 1 ~= 0 or not table.find(CatalogItem.Currencies, price.Currency) then
            table.insert(errors, where .. ": Price needs a whole Amount and a known Currency")
        end
    end
    if item.Access == "Trial" and type(item.EndsAt) ~= "number" then
        table.insert(errors, where .. ": a Trial needs EndsAt")
    end
    if item.EndsAt ~= nil and type(item.EndsAt) ~= "number" then
        table.insert(errors, where .. ": EndsAt must be a server time")
    end
    return errors
end

-- Validate a list and check ids are unique per Kind.
function CatalogItem.validateAll(items)
    local errors, seen = {}, {}
    for _, item in items do
        for _, problem in CatalogItem.validate(item) do
            table.insert(errors, problem)
        end
        if type(item) == "table" then
            local key = tostring(item.Kind) .. "/" .. tostring(item.Id)
            if seen[key] then
                table.insert(errors, key .. ": listed twice")
            end
            seen[key] = true
        end
    end
    return errors
end

-- A season track:
--   { Id, Title, Subtitle, Level = 7, Progress = 0.4 (to the next tier), EndsAt, PremiumOwned,
--     Action = "Buy" | "Claim" | "None", Price,
--     Tiers = { { Tier = 1, Free = reward | nil, Premium = reward | nil } } }
--   reward = { Title = "Skin Ticket", State = "Claimed" | "Claimable" | "Locked" | "Premium" }
function CatalogItem.validateTrack(track)
    local errors = {}
    if type(track) ~= "table" then
        return { "track is not a table" }
    end
    local where = tostring(track.Id or "?")
    local limits = CatalogItem.Limits
    text(errors, where, "Id", track.Id, 40)
    text(errors, where, "Title", track.Title, limits.Title + 12)
    text(errors, where, "Subtitle", track.Subtitle, limits.Subtitle)
    if type(track.Level) ~= "number" or track.Level < 0 then
        table.insert(errors, where .. ": Level must be a number")
    end
    if type(track.Progress) ~= "number" or track.Progress < 0 or track.Progress > 1 then
        table.insert(errors, where .. ": Progress must be 0 to 1")
    end
    if type(track.PremiumOwned) ~= "boolean" then
        table.insert(errors, where .. ": PremiumOwned must be true or false")
    end
    if not CatalogItem.Actions[track.Action] then
        table.insert(errors, where .. ": Action is not one of CatalogItem.Actions")
    end
    if track.Action == "Buy" and (type(track.Price) ~= "table" or type(track.Price.Amount) ~= "number") then
        table.insert(errors, where .. ": Buy needs Price.Amount")
    end
    if track.Action == "Buy" and track.PremiumOwned then
        table.insert(errors, where .. ": premium is owned but still on sale")
    end
    if type(track.Tiers) ~= "table" or #track.Tiers == 0 then
        table.insert(errors, where .. ": Tiers is empty")
        return errors
    end
    for index, tier in track.Tiers do
        local at = ("%s tier %d"):format(where, index)
        if type(tier) ~= "table" or tier.Tier ~= index then
            table.insert(errors, at .. ": Tier must equal its position")
        else
            for _, row in { "Free", "Premium" } do
                local reward = tier[row]
                if reward ~= nil then
                    if type(reward) ~= "table" then
                        table.insert(errors, at .. ": " .. row .. " is not a table")
                    else
                        text(errors, at .. " " .. row, "Title", reward.Title, limits.Title)
                        if not CatalogItem.RewardStates[reward.State] then
                            table.insert(errors, at .. ": " .. row .. " State is unknown")
                        elseif reward.State == "Premium" and (row == "Free" or track.PremiumOwned) then
                            table.insert(errors, at .. ": " .. row .. " cannot be premium-locked")
                        elseif reward.State ~= "Locked" and reward.State ~= "Premium" and index > track.Level then
                            table.insert(errors, at .. ": " .. row .. " is claimable above the player's level")
                        end
                    end
                end
            end
        end
    end
    return errors
end

return CatalogItem
