-- Build gate: the weapon test range (Shared/Range, RangeService, RangeController).
--
--   * the marked lanes bracket every listed gun's falloff: each has a lane at full damage and,
--     where it has a dropoff end, a lane at or past it -- otherwise the range cannot show the
--     number you came to tune
--   * the picker lists exactly the built kit guns, Primary first, no melee or utility
--   * the readout maths agrees with Weapons.DamageAt and names the right part of the curve
--   * the range sits apart from the lobby, and its entrance is on the lobby floor, clear of
--     every lobby piece and pad
--   * every range number is a Config value exposed as a Range_ Tuning attribute
--   * dummy hits are routed before Humanoid damage, and the HUD takes colours from Theme only
--
-- What it cannot check is the feel of it, the popups, or the kit's hit registration on the
-- dummies; those need Studio.
--
--     lune run tools/check_range.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local Config = require("../src/shared/Config")
local Lobby = require("../src/shared/Maps/Lobby")
local Range = require("../src/shared/Range")
local Weapons = require("../src/shared/Weapons")

local passed, failed = 0, 0
local function check(what, cond, detail)
    if cond then
        passed += 1
        print("PASS  " .. what)
    else
        failed += 1
        print("FAIL  " .. what .. (detail and ("\n        " .. tostring(detail)) or ""))
    end
end
local function near(a, b)
    return math.abs(a - b) < 1e-6
end

-- ===== lanes =====
local ordered, unique, inBounds = true, true, true
local seen = {}
local bandOrder = { CLOSE = 1, MID = 2, FAR = 3 }
local lastBand = 0
for i, lane in Range.Lanes do
    if i > 1 and lane.distance <= Range.Lanes[i - 1].distance then
        ordered = false
    end
    if seen[lane.x] then
        unique = false
    end
    seen[lane.x] = true
    if (bandOrder[lane.band] or 0) < lastBand or not bandOrder[lane.band] then
        ordered = false
    end
    lastBand = bandOrder[lane.band] or lastBand
    if math.abs(lane.x) > Range.HalfWidth - 3 or lane.distance >= Range.Front - 2 then
        inBounds = false
    end
end
check("lanes run nearest to farthest, CLOSE then MID then FAR", ordered)
check("each lane has its own column", unique)
check("every dummy stands inside the walls, short of the backstop", inBounds)

-- ===== picker =====
local function hasTool(name)
    return fs.isFile("assets/weapons/tools/" .. name .. ".rbxm")
end
local guns = Range.guns(Weapons, hasTool)
check("the picker has guns to offer", #guns > 0)

local missing = {}
for name, stats in Weapons do
    if type(stats) == "table" and stats.Type == nil and stats.Slot and hasTool(name) and not table.find(guns, name) then
        table.insert(missing, name)
    end
end
check("every built kit gun is in the picker", #missing == 0, table.concat(missing, ", "))
check("no melee or utility in the picker", not table.find(guns, "Katana") and not table.find(guns, "Jetpack"))
local primaryFirst = true
for i = 2, #guns do
    if Weapons[guns[i - 1]].Slot == "Secondary" and Weapons[guns[i]].Slot == "Primary" then
        primaryFirst = false
    end
end
check("Primary guns are listed before Secondary", primaryFirst)

-- ===== lanes bracket each gun's falloff =====
local noFull, noFloor = {}, {}
for _, name in guns do
    local s = Weapons[name]
    local full, floor = false, s.DropoffEnd == math.huge
    for _, lane in Range.Lanes do
        if lane.distance <= s.DropoffStart then
            full = true
        end
        if lane.distance >= s.DropoffEnd then
            floor = true
        end
    end
    if not full then
        table.insert(noFull, name .. " (full to " .. s.DropoffStart .. ")")
    end
    if not floor then
        table.insert(noFloor, name .. " (floor at " .. s.DropoffEnd .. ")")
    end
end
check("every gun has a lane at full damage", #noFull == 0, table.concat(noFull, ", "))
check("every gun with a dropoff has a lane at or past its end", #noFloor == 0, table.concat(noFloor, ", "))

-- ===== readout maths =====
local mathOk = true
local zoneOk = true
for _, name in guns do
    local s = Weapons[name]
    for _, d in { 0, 5, 10, 25, 37, 50, 75, 100, 150, 200, 300 } do
        for _, head in { false, true } do
            if not near(Range.specDamage(s, d, head), Weapons.DamageAt(s, d, head)) then
                mathOk = false
            end
        end
        local z = Range.zone(s, d)
        local want = d <= s.DropoffStart and "FULL" or (d >= s.DropoffEnd and "FLOOR" or "FALLOFF")
        if z ~= want then
            zoneOk = false
        end
    end
end
check("spec damage matches Weapons.DamageAt at every sampled distance", mathOk)
check("zone names the part of the curve a distance sits on", zoneOk)

local ar = Weapons.AssaultRifle
local r = Range.report(ar, 125, false, 6)
check("report: AR body at 125 studs is half-way down its falloff", near(r.Spec, 7.5) and r.Zone == "FALLOFF")
check("report: falloff is dealt over the near value", near(r.Falloff, 0.5))
local h = Range.report(ar, 10, true, 15)
check("report: a headshot is measured against the crit near value", h.Near == 15 and near(h.Falloff, 1))
check(
    "describe: every gun gets a stat card",
    (function()
        for _, name in guns do
            local d = Range.describe(Weapons[name])
            if not (d.Damage and d.Crit and d.Dropoff and d.Rate) then
                return false
            end
        end
        return true
    end)()
)

-- ===== placement =====
local function v(t)
    return Vector3.new(t[1], t[2], t[3])
end
local o = Range.Origin
check(
    "spawn is inside the range",
    Range.inside(v({ o[1] + Range.Spawn[1], o[2] + Range.Spawn[2], o[3] + Range.Spawn[3] }))
)
check("exit is inside the range", Range.inside(v({ o[1] + Range.Exit.pos[1], o[2] + 1, o[3] + Range.Exit.pos[3] })))
for _, lane in Range.Lanes do
    if not Range.inside(v({ o[1] + lane.x, o[2] + 3, o[3] + lane.distance })) then
        check("dummy at " .. lane.distance .. " is inside the range", false)
    end
end

local lo, lw, ld = Lobby.Origin, Lobby.Size[1], Lobby.Size[2]
local rangeMinZ, rangeMaxZ = o[3] + Range.Back - 2, o[3] + Range.Front + 2
local lobbyMinZ, lobbyMaxZ = lo[3] - ld / 2, lo[3] + ld / 2
local apartZ = rangeMinZ > lobbyMaxZ + 20 or rangeMaxZ < lobbyMinZ - 20
check(
    "the range does not overlap the lobby",
    apartZ,
    ("range z %d..%d, lobby z %d..%d"):format(rangeMinZ, rangeMaxZ, lobbyMinZ, lobbyMaxZ)
)
check("the range is not inside its own lobby", not Range.inside(v(lo)))

local e = Range.Entrance
local ex, ez, hx, hz = e.pos[1], e.pos[3], e.size[1] / 2, e.size[3] / 2
check("the entrance is on the lobby floor", math.abs(ex) + hx < lw / 2 - 2 and math.abs(ez) + hz < ld / 2 - 2)
local function overlaps(pos, size)
    return math.abs(pos[1] - ex) < size[1] / 2 + hx + 1 and math.abs(pos[3] - ez) < size[3] / 2 + hz + 1
end
local blocked = {}
for _, piece in Lobby.Pieces do
    if not piece.name:find("^Plate") and overlaps(piece.pos, piece.size) then
        table.insert(blocked, piece.name)
    end
end
for _, pad in Lobby.Pads do
    if overlaps(pad.pos, pad.size) then
        table.insert(blocked, pad.name)
    end
end
if Lobby.Kiosk and overlaps(Lobby.Kiosk.pos, Lobby.Kiosk.size) then
    table.insert(blocked, "Kiosk")
end
for _, s in Lobby.Spawns do
    if overlaps(s, { 2, 1, 2 }) then
        table.insert(blocked, "a spawn")
    end
end
check("the entrance is clear of every lobby piece, pad, kiosk and spawn", #blocked == 0, table.concat(blocked, ", "))

-- ===== tuning =====
local positive = true
local count = 0
for _, value in Config.Range do
    count += 1
    if type(value) ~= "number" or value <= 0 then
        positive = false
    end
end
check("Config.Range holds the range's numbers, all positive", count > 0 and positive)
local tuningSrc = fs.readFile("src/server/Services/TuningService.lua")
check("TuningService seeds Range_ attributes from Config.Range", tuningSrc:find('"Range_" .. key', 1, true) ~= nil)

-- ===== wiring =====
local weaponSrc = fs.readFile("src/server/Services/WeaponService.lua")
local routed = weaponSrc:find("IsDummy", 1, true)
local takes = weaponSrc:find("target:TakeDamage", 1, true)
check("WeaponService routes dummy hits before any Humanoid damage", routed ~= nil and takes ~= nil and routed < takes)
local hud = fs.readFile("src/client/Controllers/RangeController.lua")
check("RangeController takes every colour from Theme", hud:find("Color3.fromRGB", 1, true) == nil)
check("RangeController builds its ScreenGuis through Screen", hud:find('Instance.new("ScreenGui")', 1, true) == nil)

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    process.exit(1)
end
