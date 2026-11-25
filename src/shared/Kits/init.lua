-- Kits: one definition per kit in Kits/Registry/<Id>.lua, checked by tools/check_kits.luau.
--
-- A kit is a passive trait plus one tactical action a player picks before a match. It is a
-- sidegrade: owning one never makes a weapon stronger, and anything sold can also be bought
-- with Credits earned by playing. The rules below are the ones in
-- docs/design/kits/KIT_MINIMUM_CHECKLIST.md that a computer can check; the rest are the
-- design record's job. The workflow that writes these files is the kit-from-prompt skill.
--
--   return {
--     Id = "Neutron",                     PascalCase, the file name, never reused
--     Name = "NEUTRON",                   on the card
--     Role = "Defense",                   one of Kits.Roles
--     Fantasy = "Hold territory by resisting displacement.",
--     Decision = "When to plant and hold, and when to give ground.",   the choice it adds
--     Status = "Design",                  Design -> Built -> Verified (Kits.Statuses)
--     Access = "Purchasable",             Starter (free forever, at most one) | Purchasable
--     RotationEligible = true,            may be one of the two free weekly kits
--     Price = { Credits = 4500, Robux = true },   Credits required; Robux optional (amount in Creator Hub); nil = pending
--     Passive = {
--       Name = "INERTIAL FRAME", Text = "...", Handler = "ObjectiveKnockbackResist",
--       Tuning = { Resistance = { Default = 0.5, Min = 0, Max = 0.7, Unit = "fraction" } },
--     },
--     Tactical = {
--       Name = "DEGENERATE ARMOR", Text = "...", Handler = "FrontalBrace",
--       TouchLabel = "BRACE",             the touch button's word
--       Cooldown = { Default = 12, Min = 6, Max = 30, Unit = "s" },
--       Tuning = { ... },
--     },
--     Cost = "...",                       the price of using it: a slow, a window, a tell
--     Counter = "...",                    what an enemy does about it
--     Stacking = "...",                   two of the same kit on one team, refresh rules
--     Look = { Package = "assets/models/<name>" | nil, Note = "..." },
--   }
local Kits = {}

Kits.Roles = { "Defense", "Offense", "Mobility", "Control", "Recon", "Support", "Sustain", "Infiltration" }
Kits.Statuses = { "Design", "Built", "Verified" }
Kits.Accesses = { "Starter", "Purchasable" }

-- One action for every kit's tactical, so a player never relearns a button. Free keys at the
-- time of writing; check_kits fails if the reserved list below gains one of them.
Kits.Input = { Keyboard = "G", Gamepad = "DPadRight" }
Kits.Reserved = {
    Keyboard = { "W", "A", "S", "D", "Space", "LeftShift", "LeftControl", "C", "E", "F", "Q", "R", "V", "Tab" },
    Gamepad = {
        "ButtonA",
        "ButtonB",
        "ButtonX",
        "ButtonY",
        "ButtonR1",
        "ButtonR2",
        "ButtonL1",
        "ButtonL2",
        "ButtonL3",
        "DPadUp",
    },
}

-- Text limits match the catalog card (CatalogItem.Limits) so a kit always fits on a phone.
Kits.Limits =
    { Name = 28, Role = 48, Fantasy = 120, Decision = 160, AbilityName = 28, Text = 160, Note = 160, TouchLabel = 10 }

-- A kit may not touch a weapon's definition. Any tuning key containing one of these words
-- is refused, whatever the kit is for.
Kits.Forbidden = {
    "FireRate",
    "Recoil",
    "Spread",
    "Accuracy",
    "Magazine",
    "Ammo",
    "Reload",
    "Projectile",
    "Headshot",
    "Weapon",
    "WalkSpeed",
}

-- Ceilings on the effects most likely to turn a sidegrade into an upgrade. A key containing
-- the word has its Max checked. Raising one is a design decision for every kit, not one.
Kits.Caps = {
    { Word = "Resist", Max = 0.7, Why = "damage or knockback resistance above 70% reads as immunity" },
    { Word = "SpeedMultiplier", Max = 1.35, Why = "faster than sprint outruns every counter" },
    { Word = "Heal", Max = 60, Why = "a heal above 60 HP undoes a whole engagement" },
    { Word = "Duration", Max = 12, Why = "effects longer than 12 s stop being windows" },
}
Kits.CooldownFloor = 4 -- seconds; a tactical faster than this is a weapon, not a decision

local function isFinite(x)
    return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function text(errors, where, name, value, limit)
    if type(value) ~= "string" or value:match("^%s*$") then
        table.insert(errors, ("%s: %s must be text"):format(where, name))
    elseif value:find("TODO", 1, true) then
        table.insert(errors, ("%s: %s still says TODO"):format(where, name))
    elseif #value > limit then
        table.insert(errors, ("%s: %s is %d characters, limit %d"):format(where, name, #value, limit))
    end
end

-- A tunable number: { Default, Min, Max, Unit }.
local function number(errors, where, key, spec)
    if type(spec) ~= "table" then
        table.insert(errors, ("%s.%s: must be { Default, Min, Max, Unit }"):format(where, key))
        return
    end
    for _, field in { "Default", "Min", "Max" } do
        if not isFinite(spec[field]) then
            table.insert(errors, ("%s.%s: %s must be a finite number"):format(where, key, field))
            return
        end
    end
    if type(spec.Unit) ~= "string" or spec.Unit == "" then
        table.insert(errors, ("%s.%s: Unit must be named (s, studs, HP, fraction, multiplier)"):format(where, key))
    end
    if not (spec.Min <= spec.Default and spec.Default <= spec.Max) then
        table.insert(errors, ("%s.%s: needs Min <= Default <= Max"):format(where, key))
    end
    for _, word in Kits.Forbidden do
        if key:lower():find(word:lower(), 1, true) then
            table.insert(
                errors,
                ("%s.%s: kits may not change %s (weapon or movement definition)"):format(where, key, word)
            )
        end
    end
    for _, cap in Kits.Caps do
        if key:find(cap.Word, 1, true) and spec.Max > cap.Max then
            table.insert(
                errors,
                ("%s.%s: Max %s is over the cap %s -- %s"):format(where, key, spec.Max, cap.Max, cap.Why)
            )
        end
    end
end

local function ability(errors, where, def, isTactical)
    if type(def) ~= "table" then
        table.insert(errors, where .. ": missing")
        return
    end
    local limits = Kits.Limits
    text(errors, where, "Name", def.Name, limits.AbilityName)
    text(errors, where, "Text", def.Text, limits.Text)
    if type(def.Handler) ~= "string" or not def.Handler:match("^%u%w+$") then
        table.insert(errors, where .. ": Handler must name a server handler in PascalCase")
    end
    if def.Tuning ~= nil and type(def.Tuning) ~= "table" then
        table.insert(errors, where .. ": Tuning must be a table of numbers")
    end
    for key, spec in def.Tuning or {} do
        number(errors, where, tostring(key), spec)
    end
    if isTactical then
        text(errors, where, "TouchLabel", def.TouchLabel, limits.TouchLabel)
        number(errors, where, "Cooldown", def.Cooldown)
        if type(def.Cooldown) == "table" and isFinite(def.Cooldown.Min) and def.Cooldown.Min < Kits.CooldownFloor then
            table.insert(errors, ("%s.Cooldown: Min under %d s"):format(where, Kits.CooldownFloor))
        end
    elseif def.Cooldown ~= nil and type(def.Cooldown) ~= "table" then
        table.insert(errors, where .. ": Cooldown must be a tunable number")
    end
end

-- Returns a list of problems with one kit; an empty list means it passes.
function Kits.validate(def)
    local errors = {}
    if type(def) ~= "table" then
        return { "kit is not a table" }
    end
    local where = tostring(def.Id or "?")
    local limits = Kits.Limits
    if type(def.Id) ~= "string" or not def.Id:match("^%u%w+$") then
        table.insert(errors, where .. ": Id must be PascalCase letters and digits")
    end
    text(errors, where, "Name", def.Name, limits.Name)
    text(errors, where, "Fantasy", def.Fantasy, limits.Fantasy)
    text(errors, where, "Decision", def.Decision, limits.Decision)
    text(errors, where, "Cost", def.Cost, limits.Text)
    text(errors, where, "Counter", def.Counter, limits.Text)
    text(errors, where, "Stacking", def.Stacking, limits.Text)
    if not table.find(Kits.Roles, def.Role) then
        table.insert(errors, where .. ": Role is not one of Kits.Roles")
    end
    if not table.find(Kits.Statuses, def.Status) then
        table.insert(errors, where .. ": Status is not one of Kits.Statuses")
    end
    if not table.find(Kits.Accesses, def.Access) then
        table.insert(errors, where .. ": Access is not one of Kits.Accesses")
    end
    if type(def.RotationEligible) ~= "boolean" then
        table.insert(errors, where .. ": RotationEligible must be true or false")
    elseif def.Access == "Starter" and def.RotationEligible then
        table.insert(errors, where .. ": a starter kit cannot take a rotation slot")
    end

    local price = def.Price
    if price ~= nil then
        if type(price) ~= "table" then
            table.insert(errors, where .. ": Price must be { Credits = n } or left out while pending")
        else
            -- Robux is an optional second way to pay, never the only one: nothing with gameplay
            -- is Robux-only. The Robux amount lives in Creator Hub, never in code, so the data
            -- only says `Robux = true`.
            for currency, amount in price do
                if currency == "Credits" then
                    if not isFinite(amount) or amount <= 0 or amount % 1 ~= 0 then
                        table.insert(errors, where .. ": Price.Credits must be a whole number above 0")
                    end
                elseif currency == "Robux" then
                    if amount ~= true then
                        table.insert(
                            errors,
                            where .. ": Price.Robux is true or absent; its amount is set in Creator Hub"
                        )
                    elseif price.Credits == nil then
                        table.insert(errors, where .. ": a Robux price needs a Credits price too; no kit is Robux-only")
                    end
                else
                    table.insert(
                        errors,
                        ("%s: Price in %s; kits use Credits, optionally Robux"):format(where, tostring(currency))
                    )
                end
            end
        end
        if def.Access == "Starter" then
            table.insert(errors, where .. ": a starter kit has no price")
        end
    end

    ability(errors, where .. ".Passive", def.Passive, false)
    ability(errors, where .. ".Tactical", def.Tactical, true)

    if def.Look ~= nil then
        if type(def.Look) ~= "table" then
            table.insert(errors, where .. ": Look must be a table")
        elseif
            def.Look.Package ~= nil and (type(def.Look.Package) ~= "string" or not def.Look.Package:match("^assets/"))
        then
            table.insert(errors, where .. ": Look.Package must be a path under assets/")
        end
    end
    return errors
end

-- Checks across the whole registry: one starter at most, the shared input is still free.
function Kits.validateAll(defs)
    local errors, starters = {}, {}
    for _, def in defs do
        if type(def) == "table" and def.Access == "Starter" then
            table.insert(starters, tostring(def.Id))
        end
    end
    if #starters > 1 then
        table.insert(errors, "more than one starter kit: " .. table.concat(starters, ", "))
    end
    for device, key in Kits.Input do
        if table.find(Kits.Reserved[device] or {}, key) then
            table.insert(errors, ("Kits.Input.%s = %s is already bound elsewhere"):format(device, key))
        end
    end
    return errors
end

-- The catalog card for a kit. Access and Action are the server's answer for one player
-- (CatalogItem.Access / CatalogItem.Actions); this only supplies the words.
function Kits.toCatalogItem(def, access, action, selected)
    local sections = {
        { Heading = "PASSIVE - " .. def.Passive.Name, Body = def.Passive.Text },
        { Heading = "TACTICAL - " .. def.Tactical.Name, Body = def.Tactical.Text },
        { Heading = "COUNTER", Body = def.Counter },
    }
    local item = {
        Id = def.Id,
        Kind = "Kit",
        Title = def.Name,
        Subtitle = def.Role,
        Summary = def.Fantasy,
        Sections = sections,
        Access = access,
        Action = action,
        Selected = selected == true,
    }
    if action == "Buy" and def.Price and def.Price.Credits then
        item.Price = { Amount = def.Price.Credits, Currency = "Credits" }
    end
    return item
end

-- What the card says before the store exists: a priced kit is Locked/Buy, an unpriced one
-- is ComingSoon. Used by the gate and the gallery; the server replaces it per player.
function Kits.defaultCard(def)
    if def.Access == "Starter" then
        return Kits.toCatalogItem(def, "Starter", "Equip", false)
    end
    if def.Price and def.Price.Credits then
        return Kits.toCatalogItem(def, "Locked", "Buy", false)
    end
    return Kits.toCatalogItem(def, "ComingSoon", "None", false)
end

return Kits
