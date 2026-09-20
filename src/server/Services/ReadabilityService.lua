-- Combat readability, NOT avatar standardization. Players keep their cosmetics; what this does is
-- make friend/enemy and body orientation readable at combat distance when someone is wearing
-- something that destroys their silhouette.
--
-- Two treatments, both match-only. Lobby avatars are never touched, and because RoundService
-- reloads the character on the way back to the lobby, accessories rebuild clean -- so nothing here
-- needs to store and restore original values.
--
-- 1. A restrained team-coloured Highlight. Deliberately weaker than the Titan glow on every axis:
--
--        treatment        Fill   Outline   Through walls
--        normal player    0.93   0.55      no  (Occluded)
--        Titan            0.75   0.00      yes (MutationService)
--
--    Occluded matters: AlwaysOnTop would let players track enemies through geometry. The Titan is
--    the deliberate exception -- a transformation is meant to be a match-wide event.
--
-- 2. Effect taming judged by OUTPUT, not by category. "Remove particle accessories" is the wrong
--    rule: a modest particle trail is harmless while giant wings emit nothing at all. So this
--    clamps emitters, trails and lights that exceed a budget, and leaves everything else alone.
--    Oversized *geometry* is the known remaining gap -- see the note at the bottom.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ReadabilityService = Knit.CreateService({ Name = "ReadabilityService" })

local TEAM_COLORS = {
    Red = Color3.fromRGB(255, 70, 70),
    Blue = Color3.fromRGB(70, 140, 255),
}

local DEFAULTS = {
    Readability_Outline = true,
    Readability_OutlineTransparency = 0.55,
    Readability_FillTransparency = 0.93,
    Readability_TameEffects = true,
    Readability_MaxParticleRate = 15,
    Readability_MaxParticleSize = 1.5,
    Readability_MaxTrailLifetime = 0.4,
    Readability_MaxLightBrightness = 1,
    Readability_MaxLightRange = 8,
}

local function tuning()
    return ReplicatedStorage:FindFirstChild("Tuning")
end

local function setting(key)
    local t = tuning()
    local v = t and t:GetAttribute(key)
    if v == nil then
        return DEFAULTS[key]
    end
    return v
end

-- Only cosmetics get tamed. Gameplay VFX (MutantGlow, MutantCore, weapon effects) are not
-- inside an Accessory, so this never touches them.
local function insideAccessory(inst: Instance): boolean
    local cursor = inst.Parent
    while cursor do
        if cursor:IsA("Accessory") then
            return true
        end
        if cursor:IsA("Model") then -- reached the character without finding one
            return false
        end
        cursor = cursor.Parent
    end
    return false
end

local function maxOfSequence(seq: NumberSequence): number
    local peak = 0
    for _, kp in seq.Keypoints do
        peak = math.max(peak, kp.Value)
    end
    return peak
end

function ReadabilityService:TameEffects(character: Model)
    if setting("Readability_TameEffects") ~= true then
        return
    end
    local maxRate = setting("Readability_MaxParticleRate")
    local maxSize = setting("Readability_MaxParticleSize")
    local maxTrail = setting("Readability_MaxTrailLifetime")
    local maxBright = setting("Readability_MaxLightBrightness")
    local maxRange = setting("Readability_MaxLightRange")

    for _, d in character:GetDescendants() do
        if not insideAccessory(d) then
            continue
        end
        if d:IsA("ParticleEmitter") then
            -- judged on output: a low-rate, small emitter is left exactly as the player chose it
            if d.Rate > maxRate then
                d.Rate = maxRate
            end
            if maxOfSequence(d.Size) > maxSize then
                d.Size = NumberSequence.new(maxSize)
            end
        elseif d:IsA("Trail") then
            if d.Lifetime > maxTrail then
                d.Lifetime = maxTrail
            end
        elseif d:IsA("Beam") then
            d.Enabled = false -- a beam across the body is silhouette noise with no cosmetic value
        elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
            d.Brightness = math.min(d.Brightness, maxBright)
            d.Range = math.min(d.Range, maxRange)
        end
    end
end

function ReadabilityService:ApplyOutline(player: Player, character: Model)
    if setting("Readability_Outline") ~= true then
        return
    end
    local team = player:GetAttribute("Team")
    local color = TEAM_COLORS[team]
    if not color then
        return
    end
    local existing = character:FindFirstChild("TeamOutline")
    if existing then
        existing:Destroy()
    end
    local hl = Instance.new("Highlight")
    hl.Name = "TeamOutline"
    hl.FillColor = color
    hl.FillTransparency = setting("Readability_FillTransparency")
    hl.OutlineColor = color
    hl.OutlineTransparency = setting("Readability_OutlineTransparency")
    hl.DepthMode = Enum.HighlightDepthMode.Occluded -- never through walls
    hl.Parent = character

    -- The Titan transformation owns the silhouette while it lasts. Two Highlights on one model
    -- fight each other, so this one stands down rather than diluting the transformation.
    local function sync()
        hl.Enabled = character:FindFirstChild("MutantGlow") == nil
    end
    character.ChildAdded:Connect(sync)
    character.ChildRemoved:Connect(sync)
    sync()
end

function ReadabilityService:Apply(player: Player, character: Model)
    if not player:GetAttribute("InMatch") then
        return -- lobby avatars are left completely alone
    end
    self:TameEffects(character)
    self:ApplyOutline(player, character)
end

function ReadabilityService:KnitStart()
    local function watch(player: Player)
        player.CharacterAdded:Connect(function(character)
            -- accessories stream in after the character, so give them a beat to arrive
            task.defer(function()
                task.wait(0.35)
                if character.Parent then
                    self:Apply(player, character)
                end
            end)
        end)
    end
    for _, p in Players:GetPlayers() do
        watch(p)
    end
    Players.PlayerAdded:Connect(watch)
end

-- Known gap, deliberately not implemented yet: accessories whose GEOMETRY substantially exceeds the
-- character silhouette (oversized wings, spikes) emit nothing and so pass every check above. Judging
-- those needs a bounding-box comparison against the character and a decision about what to do with a
-- violator -- scale it, hide it, or leave it. That is a product decision, not a threshold.
return ReadabilityService
