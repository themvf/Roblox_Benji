-- Movement speed, decided in one place.
--
-- Before this, four things wrote Humanoid.WalkSpeed directly -- Brace, the speed pickup,
-- celebrations and the Weapons Kit's camera -- each saving "the base" and writing it back
-- later. Overlap two and the second restored a stale value: a speed pickup during Brace
-- left the player at 0.6x or 1.25x for good, and the kit silently overwrote all of them
-- every frame while a gun was out.
--
-- Now a speed effect is a multiplier stored as a character attribute, SpeedMul_<Source>
-- (Brace 0.6, Pickup 1.25, Celebration 0). Servers set and clear them; nothing else
-- writes WalkSpeed. The walk speed is
--
--     WalkSpeed x product(SpeedMul_*) x stance (sprint / crouch / aim)
--
-- applied by MovementController for players (their characters are client-owned, and
-- sprint must respond instantly) and by `apply` below for bots, which the server owns.
-- The order modifiers start and end in no longer matters.
local Movement = {}

Movement.PREFIX = "SpeedMul_"

-- Stances a character can be in. Sprint/Crouch/Slide are replicated as the character's
-- `Stance` attribute (nil = walking) so every client can pose crouching and sliding.
Movement.STANCES = { Sprint = true, Crouch = true, Slide = true }

local KEYS = {
    "WalkSpeed",
    "SprintMultiplier",
    "AimMultiplier",
    "CrouchMultiplier",
    "SlideSpeed",
    "SlideSeconds",
    "SlideCooldown",
    "AutoSprintTouch",
    "AutoSprintDesktop",
}
Movement.KEYS = KEYS

-- Valid ranges. An out-of-range or non-finite Tuning value falls back to the default
-- instead of launching players at infinite speed.
local RANGE = {
    WalkSpeed = { 4, 60 },
    SprintMultiplier = { 1, 3 },
    AimMultiplier = { 0.1, 1 },
    CrouchMultiplier = { 0.1, 1 },
    SlideSpeed = { 10, 120 },
    SlideSeconds = { 0.1, 3 },
    SlideCooldown = { 0, 10 },
}

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Current settings: Tuning attributes (Movement_<Key>) over Config.Movement defaults.
-- `tuning` is the Configuration instance, or nil.
function Movement.settings(defaults, tuning)
    local out = {}
    for _, key in KEYS do
        local value = tuning and tuning:GetAttribute("Movement_" .. key)
        local default = defaults[key]
        if type(default) == "boolean" then
            out[key] = if type(value) == "boolean" then value else default
        else
            local range = RANGE[key]
            if finite(value) and value >= range[1] and value <= range[2] then
                out[key] = value
            else
                out[key] = default
            end
        end
    end
    return out
end

-- Product of every SpeedMul_* attribute on a character. Malformed values are ignored.
function Movement.modifiers(character)
    local product = 1
    for name, value in character:GetAttributes() do
        if name:sub(1, #Movement.PREFIX) == Movement.PREFIX and finite(value) and value >= 0 then
            product *= value
        end
    end
    return product
end

-- The walk speed for a stance. Slide is driven by velocity, so its walk speed is crouch
-- speed (what it fades to). Aiming cancels sprint.
function Movement.resolve(settings, modifiers, stance, aiming)
    local speed = settings.WalkSpeed * modifiers
    if stance == "Crouch" or stance == "Slide" then
        speed *= settings.CrouchMultiplier
    elseif stance == "Sprint" and not aiming then
        speed *= settings.SprintMultiplier
    end
    if aiming then
        speed *= settings.AimMultiplier
    end
    return speed
end

-- Slide speed `t` seconds into a slide: eases out from SlideSpeed to crouch speed.
function Movement.slideSpeed(settings, modifiers, t)
    local finish = settings.WalkSpeed * settings.CrouchMultiplier * modifiers
    local start = math.max(settings.SlideSpeed * modifiers, finish)
    local a = math.clamp(t / settings.SlideSeconds, 0, 1)
    return start + (finish - start) * (1 - (1 - a) * (1 - a))
end

-- Server side: start (value) or end (nil) a speed effect. `isPlayer` is whether the
-- character belongs to a player; a bot's WalkSpeed is applied here, a player's by their
-- own client. Bots keep their base speed in the BaseWalkSpeed attribute.
function Movement.setModifier(character, source, value, isPlayer)
    character:SetAttribute(Movement.PREFIX .. source, value)
    if not isPlayer then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = (character:GetAttribute("BaseWalkSpeed") or 16) * Movement.modifiers(character)
        end
    end
end

return Movement
