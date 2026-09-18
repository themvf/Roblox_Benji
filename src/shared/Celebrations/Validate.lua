-- Celebration validator: the Game-ending celebrations section of the spec as code.
-- Pure Luau; runs in Lune (tools/check_celebrations.luau) and in the game.
--
-- A celebration is a table:
--   Id        "cel_<tier>_<concept>"  (tier short: common | rare | leg | myth)
--   Tier      "Common" | "Rare" | "Legendary" | "Mythical"
--   Name      display name
--   Concept   one sentence; the concept word in the Id must appear in it
--   Length    seconds; <= tier cap (4 / 6 / 8 / 8)
--   Flashing  "none" | "low" | "high"   (accessibility rating, required)
--   Systems   { Motion = {...}, Audio?, Effects?, Props?, Camera?, Reactive? }
local Validate = {}

Validate.SYSTEMS = { "Motion", "Audio", "Effects", "Props", "Camera", "Reactive" }

Validate.TIERS = {
    { Name = "Common", Short = "common", May = { "Motion" }, Must = { "Motion" }, MaxLength = 4 },
    {
        Name = "Rare",
        Short = "rare",
        May = { "Motion", "Audio", "Effects" },
        Must = { "Motion" },
        MustOneOf = { "Audio", "Effects" },
        MaxLength = 6,
    },
    {
        Name = "Legendary",
        Short = "leg",
        May = { "Motion", "Audio", "Effects", "Props" },
        Must = { "Motion", "Audio", "Effects", "Props" },
        MaxLength = 8,
    },
    {
        Name = "Mythical",
        Short = "myth",
        May = Validate.SYSTEMS,
        Must = Validate.SYSTEMS,
        MaxLength = 8,
    },
}

Validate.MAX_LENGTH = 8

-- Guardrail: nothing in a celebration targets an opponent. These keys are refused anywhere.
Validate.FORBIDDEN_KEYS = { "Target", "Opponent", "Loser", "TargetPlayer", "TargetName", "Taunt" }

local function has(list, v)
    return table.find(list, v) ~= nil
end

local function tierByName(name)
    for _, t in Validate.TIERS do
        if t.Name == name then
            return t
        end
    end
    return nil
end

function Validate.minimalTier(systems)
    for _, tier in Validate.TIERS do
        local ok = true
        for _, sys in systems do
            if not has(tier.May, sys) then
                ok = false
                break
            end
        end
        if ok then
            return tier
        end
    end
    return nil
end

local function findForbidden(tbl, path, out, depth)
    if depth > 6 or type(tbl) ~= "table" then
        return
    end
    for k, v in tbl do
        if type(k) == "string" and has(Validate.FORBIDDEN_KEYS, k) then
            table.insert(out, path .. "." .. k)
        end
        findForbidden(v, path .. "." .. tostring(k), out, depth + 1)
    end
end

function Validate.check(cel)
    local errors = {}
    local function fail(msg)
        table.insert(errors, msg)
    end
    if type(cel) ~= "table" then
        return false, { "celebration is not a table" }, {}
    end
    if type(cel.Id) ~= "string" then
        fail("Id missing")
    end
    local tier = type(cel.Tier) == "string" and tierByName(cel.Tier) or nil
    if not tier then
        fail("Tier must be Common, Rare, Legendary or Mythical; got " .. tostring(cel.Tier))
    end
    if type(cel.Name) ~= "string" or #cel.Name == 0 then
        fail("Name missing")
    end
    if type(cel.Concept) ~= "string" or #cel.Concept < 10 then
        fail("Concept sentence missing")
    end
    if type(cel.Length) ~= "number" or cel.Length <= 0 then
        fail("Length (seconds) missing")
    elseif cel.Length > Validate.MAX_LENGTH then
        fail("Length over the 8 s cap: " .. cel.Length)
    elseif tier and cel.Length > tier.MaxLength then
        fail(("Length %s s over the %s cap of %s s"):format(cel.Length, tier.Name, tier.MaxLength))
    end
    if cel.Flashing ~= "none" and cel.Flashing ~= "low" and cel.Flashing ~= "high" then
        fail("Flashing rating must be none, low or high")
    end

    local systems = {}
    if type(cel.Systems) ~= "table" then
        fail("Systems table missing")
    else
        for name, def in cel.Systems do
            if not has(Validate.SYSTEMS, name) then
                fail("Unknown system: " .. tostring(name))
            elseif type(def) ~= "table" then
                fail("System " .. name .. " must be a table")
            else
                table.insert(systems, name)
            end
        end
    end
    table.sort(systems)

    local forbidden = {}
    findForbidden(cel.Systems or {}, "Systems", forbidden, 0)
    for _, path in forbidden do
        fail("Celebrations never target an opponent: " .. path)
    end

    -- Motion must start and end on the spot with a hold pose
    local motion = cel.Systems and cel.Systems.Motion
    if type(motion) == "table" then
        if not motion.Emote and not motion.Animation then
            fail("Motion needs an Emote name or an Animation id")
        end
        if motion.HoldPose == nil then
            fail("Motion needs HoldPose (the end pose that frames the face)")
        end
    end
    -- Props must despawn within the cap
    local props = cel.Systems and cel.Systems.Props
    if type(props) == "table" then
        if type(props.DespawnAt) ~= "number" or props.DespawnAt > Validate.MAX_LENGTH then
            fail("Props.DespawnAt must be a number <= 8")
        end
    end
    -- Camera returns to results framing by the cap
    local camera = cel.Systems and cel.Systems.Camera
    if type(camera) == "table" then
        if type(camera.ReturnAt) ~= "number" or camera.ReturnAt > Validate.MAX_LENGTH then
            fail("Camera.ReturnAt must be a number <= 8")
        end
    end

    local minimal = Validate.minimalTier(systems)
    if tier and minimal and tier.Name ~= minimal.Name then
        fail(("Tier is %s but the lowest admitting tier is %s"):format(tier.Name, minimal.Name))
    elseif tier and not minimal then
        fail("No tier admits this system set: " .. table.concat(systems, ", "))
    end
    if tier then
        for _, sys in tier.Must or {} do
            if not has(systems, sys) then
                fail(tier.Name .. " must include " .. sys)
            end
        end
        if tier.MustOneOf then
            local any = false
            for _, sys in tier.MustOneOf do
                if has(systems, sys) then
                    any = true
                end
            end
            if not any then
                fail(tier.Name .. " must include one of " .. table.concat(tier.MustOneOf, " or "))
            end
        end
    end

    if type(cel.Id) == "string" and tier then
        local t, c = cel.Id:match("^cel_([a-z]+)_([a-z0-9]+)$")
        if not t then
            fail("Id must look like cel_<tier>_<concept>: " .. cel.Id)
        else
            if t ~= tier.Short then
                fail("Id tier segment '" .. t .. "' should be '" .. tier.Short .. "'")
            end
            if type(cel.Concept) == "string" and not cel.Concept:lower():find(c, 1, true) then
                fail("Concept word '" .. c .. "' does not appear in the concept sentence")
            end
        end
    end

    return #errors == 0, errors, { Systems = systems, MinimalTier = minimal and minimal.Name or nil }
end

return Validate
