-- Weapon test range: layout data and the pure maths behind its hit readout.
--
-- A walled lane block beside the lobby. Every gun with a built tool can be equipped instantly,
-- ammo never runs out, and dummies stand at marked distances so a hit can be read against the
-- weapon's own falloff numbers in Shared/Weapons. It is not a map: it is never in a rotation,
-- the map validator does not see it (it lives outside Shared/Maps on purpose), and nothing in
-- it decides a fight.
--
-- Positions are relative to Origin. The firing line is z = 0 and the lanes run toward +Z, so a
-- dummy's marked distance is simply its z.
--
-- Tunable numbers (dummy health, reset times) are in Config.Range and exposed as Range_<Key>
-- attributes on ReplicatedStorage.Tuning.
local Range = {}

Range.Origin = { 0, 400, 1300 }

-- Half-width of the floor and the z extent, used for the floor, the walls and inside().
Range.HalfWidth = 48
Range.Back = -26 -- behind the firing line: spawn, exit booth
Range.Front = 226 -- past the farthest dummy: the backstop

-- One lane per marked distance. Bands are the labels a player tunes against: CLOSE is
-- shotgun range, MID is where most rifles start to fall off, FAR is past most dropoff ends.
-- check_range requires these to bracket every gun's DropoffStart and DropoffEnd.
Range.Lanes = {
    { distance = 10, band = "CLOSE", x = -37.5 },
    { distance = 25, band = "CLOSE", x = -22.5 },
    { distance = 50, band = "MID", x = -7.5 },
    { distance = 100, band = "MID", x = 7.5 },
    { distance = 150, band = "FAR", x = 22.5 },
    { distance = 200, band = "FAR", x = 37.5 },
}

-- A floor line every Marker studs, numbered, across all lanes.
Range.Marker = 25

-- Where you appear, facing down the lanes.
Range.Spawn = { 0, 3, -10 }

-- The way in, built in the lobby beside the Armory. Relative to the Lobby's Origin, not this one.
Range.Entrance = { pos = { -50, 0, 44 }, size = { 12, 1, 8 } }

-- The way out, at the back of the range.
Range.Exit = { pos = { 0, 0, -22 }, size = { 12, 1, 4 } }

Range.Palette = {
    Floor = Color3.fromRGB(46, 50, 60),
    Lane = Color3.fromRGB(38, 42, 52),
    Line = Color3.fromRGB(90, 96, 112),
    Wall = Color3.fromRGB(38, 42, 52),
    Accent = Color3.fromRGB(255, 196, 70), -- firing line, entrance: interact / CTA only
    Dummy = Color3.fromRGB(196, 168, 120),
    DummyHead = Color3.fromRGB(226, 198, 150),
    DummyDown = Color3.fromRGB(90, 80, 70),
    Health = Color3.fromRGB(90, 230, 130),
    HealthLow = Color3.fromRGB(255, 90, 50),
    Track = Color3.fromRGB(45, 48, 58),
    Text = Color3.fromRGB(245, 245, 250),
    Close = Color3.fromRGB(120, 200, 160),
    Mid = Color3.fromRGB(255, 196, 70),
    Far = Color3.fromRGB(255, 120, 90),
}

-- Is a position (world space) inside the range?
function Range.inside(position)
    local o = Range.Origin
    local x, y, z = position.X - o[1], position.Y - o[2], position.Z - o[3]
    return math.abs(x) <= Range.HalfWidth + 1 and z >= Range.Back - 1 and z <= Range.Front + 1 and y > -10 and y < 60
end

-- The guns the picker offers: kit guns (no Type) in the Primary and Secondary slots that have a
-- built tool. Melee and utility items are left out -- MeleeService only swings at players, and a
-- jetpack has nothing to read. Primary first, then Secondary, alphabetical within each.
function Range.guns(weapons, hasTool)
    local out = {}
    for name, stats in weapons do
        if
            type(stats) == "table"
            and stats.Type == nil
            and (stats.Slot == "Primary" or stats.Slot == "Secondary")
            and hasTool(name)
        then
            table.insert(out, name)
        end
    end
    table.sort(out, function(a, b)
        local sa, sb = weapons[a].Slot, weapons[b].Slot
        if sa ~= sb then
            return sa == "Primary"
        end
        return a < b
    end)
    return out
end

-- Which part of a weapon's falloff curve a distance sits on.
--   FULL     inside DropoffStart: full damage
--   FALLOFF  between start and end: scaling down
--   FLOOR    at or past DropoffEnd: the far value
function Range.zone(stats, distance)
    if distance <= stats.DropoffStart then
        return "FULL"
    elseif distance >= stats.DropoffEnd then
        return "FLOOR"
    end
    return "FALLOFF"
end

-- Rivals-spec damage for one pellet at a distance (same formula as Weapons.DamageAt, kept here so
-- this module has no requires and loads in Lune).
function Range.specDamage(stats, distance, headshot)
    local pair = headshot and stats.Crit or stats.Damage
    local near, far = pair[1], pair[2]
    if distance <= stats.DropoffStart then
        return near
    end
    if distance >= stats.DropoffEnd then
        return far
    end
    local t = (distance - stats.DropoffStart) / (stats.DropoffEnd - stats.DropoffStart)
    return near + (far - near) * t
end

-- Everything the readout says about one pellet. `dealt` is what the game actually took off the
-- dummy (the Weapons Kit's falloff, then our crit multiplier); `Spec` is what Shared/Weapons says
-- it should be. They differ past DropoffEnd: the kit keeps falling toward zero instead of holding
-- the far value, and the readout shows that rather than hiding it.
function Range.report(stats, distance, headshot, dealt)
    local near = (headshot and stats.Crit or stats.Damage)[1]
    return {
        Near = near,
        Spec = Range.specDamage(stats, distance, headshot),
        Falloff = near > 0 and dealt / near or 0,
        Zone = Range.zone(stats, distance),
    }
end

-- Short summary of a gun's numbers for the picker and the readout.
function Range.describe(stats)
    local function n(v)
        if v == math.huge then
            return "inf"
        end
        return (v == math.floor(v)) and tostring(v) or ("%.1f"):format(v)
    end
    local dropoff = stats.DropoffStart == math.huge and "no falloff"
        or ("full to %s, floor at %s studs"):format(n(stats.DropoffStart), n(stats.DropoffEnd))
    local pellets = (stats.Pellets or 1) > 1 and (" x%d pellets"):format(stats.Pellets) or ""
    return {
        Damage = ("body %s > %s%s"):format(n(stats.Damage[1]), n(stats.Damage[2]), pellets),
        Crit = ("head %s > %s"):format(n(stats.Crit[1]), n(stats.Crit[2])),
        Dropoff = dropoff,
        Rate = ("%s s/shot%s%s"):format(
            n(stats.Cooldown),
            stats.Burst and (", burst " .. stats.Burst) or "",
            stats.Auto and ", auto" or ""
        ),
    }
end

return Range
