-- Studio-editable knobs. On start this creates (if missing) two things Rojo never overwrites:
--   ReplicatedStorage.Tuning   a Configuration whose attributes override Shared/Config values
--                              (RoundSeconds, RoundsToWin, IntermissionSeconds, ...). Edit them in
--                              the Properties panel; the game reads them live.
--   ReplicatedStorage.Uploads  a folder to drop Decals, Sounds and Animations into, referenced by
--                              name as "upload:<Name>" from skins and celebrations.
-- Both live outside the Rojo project tree so Studio edits persist across syncs and publishes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local TuningService = Knit.CreateService({ Name = "TuningService" })

-- Keys exposed as attributes and their defaults from Config
local TUNABLE = {
    "IntermissionSeconds",
    "RoundSeconds",
    "RoundsToWin",
    "RespawnSeconds",
    "UseBakedMaps",
    "MapVoteEnabled",
    "MapVoteSeconds",
    "MapVoteOptions",
}

-- Idempotent, and safe to call from another service's KnitInit: Knit gives no ordering
-- guarantee between services, and MapService builds the map (reading Tuning) in its own
-- KnitInit, which can run before this one.
function TuningService:EnsureSetup()
    if self.Ready then
        return
    end
    self.Ready = true

    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    if not tuning then
        tuning = Instance.new("Configuration")
        tuning.Name = "Tuning"
        tuning.Parent = ReplicatedStorage
    end
    if tuning:GetAttribute("UI_ReducedMotion") == nil then
        tuning:SetAttribute("UI_ReducedMotion", false)
    end
    -- StartupMap is not a tunable. The map is built once, in MapService:KnitInit, so
    -- changing an attribute mid-session does nothing anyway -- and because a saved
    -- attribute beats Config forever, a value set in some earlier session silently won
    -- over every later edit to Config.lua. That cost three separate rounds of "why am I
    -- looking at the wrong map", each one ending in deleting the attribute by hand,
    -- which does not stick when it is deleted from a running session.
    --
    -- Shared/Config.lua is the only source now. Clear whatever an older place file
    -- still carries, before MapService reads it: EnsureSetup runs first by contract.
    local stale = tuning:GetAttribute("StartupMap")
    if stale ~= nil then
        tuning:SetAttribute("StartupMap", nil)
        print(
            ("[Tuning] cleared a saved StartupMap of %q; the startup map now comes only "):format(tostring(stale))
                .. "from Shared/Config.lua. Edit it there and restart the server."
        )
    end
    -- A saved attribute wins over Shared/Config forever, because seeding only fills
    -- a nil. That is the point -- Studio tuning should survive a sync -- but it also
    -- means editing Config.lua can look like it did nothing at all. Say so once at
    -- startup for anything that disagrees, naming both values.
    for _, key in TUNABLE do
        local current = tuning:GetAttribute(key)
        if current == nil then
            tuning:SetAttribute(key, Config[key])
        elseif current ~= Config[key] then
            print(
                ("[Tuning] %s = %s (overriding Config's %s). Clear the attribute on "):format(
                    key,
                    tostring(current),
                    tostring(Config[key])
                ) .. "ReplicatedStorage.Tuning to follow the file again."
            )
        end
    end
    -- dev switches (Carrier Testability & Safety Fix Spec v1)
    if tuning:GetAttribute("Debug_ForceMap") == nil then
        tuning:SetAttribute("Debug_ForceMap", "")
    end
    if tuning:GetAttribute("Debug_CarrierTestSafety") == nil then
        tuning:SetAttribute("Debug_CarrierTestSafety", true)
    end
    -- Debug_ForceCarrier, MapVote_Enabled, MapVote_Seconds and MapVote_Candidates used to be
    -- seeded here and are deliberately gone: nothing in src/ has read any of them for some time.
    -- They showed up in the Tuning Properties panel one line away from the live keys
    -- (MapVoteOptions, MapVoteSeconds, MapVoteEnabled, Debug_ForceMap), so the obvious way to
    -- change the ballot size was to edit MapVote_Candidates, which does nothing at all.
    -- Removing the seed stops new places growing them; a place that already has them keeps them
    -- until they are deleted on the Configuration by hand.
    -- PhaseSeconds cannot be an attribute (arrays are not attribute-legal), so it is exposed as
    -- two scalars. The final phase is derived from Convergence_HardCapSeconds minus phases 1/2.
    -- A legacy Phase3Seconds attribute, if present, is not used.
    local phases = Config.Convergence.PhaseSeconds or { 180, 180, 180 }
    for i = 1, 2 do
        local key = ("Convergence_Phase%dSeconds"):format(i)
        if tuning:GetAttribute(key) == nil then
            tuning:SetAttribute(key, phases[i] or 180)
        end
    end
    -- arena camera framing (CameraController) -- experiment, tune while moving
    for key, default in
        {
            Camera_ArenaFraming = true,
            Camera_Zoom = 14,
            Camera_MinZoom = 10,
            Camera_MaxZoom = 20,
            Camera_HeightOffset = 1.5,
        }
    do
        if tuning:GetAttribute(key) == nil then
            tuning:SetAttribute(key, default)
        end
    end
    -- combat readability (ReadabilityService): restrained team outline + effect taming
    for key, default in
        {
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
    do
        if tuning:GetAttribute(key) == nil then
            tuning:SetAttribute(key, default)
        end
    end
    if tuning:GetAttribute("Debug_CountBotMatches") == nil then
        tuning:SetAttribute("Debug_CountBotMatches", true) -- dev: bot matches count for stats/streaks
    end
    if tuning:GetAttribute("Debug_ForceTouchUi") == nil then
        tuning:SetAttribute("Debug_ForceTouchUi", false) -- dev: show the phone/tablet touch HUD on PC
    end
    local conv = Config.Convergence
    for _, key in Config.CONVERGENCE_TUNABLE do
        if tuning:GetAttribute("Convergence_" .. key) == nil then
            tuning:SetAttribute("Convergence_" .. key, conv[key])
        end
    end
    local note = tuning:FindFirstChild("README")
    if not note then
        note = Instance.new("StringValue")
        note.Name = "README"
        note.Value =
            "Edit the attributes on this Configuration (Properties panel) to tune the game. Changes apply to the next round or match."
        note.Parent = tuning
    end
    Config.SetOverrideSource(tuning)

    local uploads = Uploads.folder()
    if not uploads then
        uploads = Instance.new("Folder")
        uploads.Name = Uploads.FOLDER_NAME
        uploads.Parent = ReplicatedStorage
        local guide = Instance.new("StringValue")
        guide.Name = "README"
        guide.Value =
            "Drop Decals (images), Sounds and Animations here. Name them, then reference as upload:<Name> from skins and celebrations. Expected today: BlueCamo (Decal)."
        guide.Parent = uploads
    end
end

function TuningService:KnitInit()
    self:EnsureSetup()
end

return TuningService
