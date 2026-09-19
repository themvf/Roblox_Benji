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
    "StartupMap",
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
    for _, key in TUNABLE do
        if tuning:GetAttribute(key) == nil then
            tuning:SetAttribute(key, Config[key])
        end
    end
    -- dev switches (Carrier Testability & Safety Fix Spec v1)
    if tuning:GetAttribute("Debug_ForceMap") == nil then
        tuning:SetAttribute("Debug_ForceMap", "")
    end
    if tuning:GetAttribute("Debug_CarrierTestSafety") == nil then
        tuning:SetAttribute("Debug_CarrierTestSafety", true)
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
