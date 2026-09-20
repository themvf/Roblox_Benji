-- Arena third-person framing. Roblox's default sits close behind the head, which puts the
-- avatar across a large share of the lower-middle viewport -- the more so with oversized
-- cosmetics, where wings and spikes cover both the character and the ground behind them.
--
-- Pulling the camera back and up is a cleaner answer than fighting avatar customization: it
-- shrinks every avatar's screen footprint at once, widens peripheral awareness, shows more of
-- the arena, and opens the space around the crosshair.
--
-- This is an EXPERIMENT and camera distance materially changes combat feel, so every number is
-- a Tuning attribute and `Camera_ArenaFraming` turns the whole thing off. Judge it while
-- strafing and acquiring targets, not standing still.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local CameraController = Knit.CreateController({ Name = "CameraController" })

local DEFAULTS = {
    Camera_ArenaFraming = true,
    Camera_Zoom = 14, -- default is 12.5 and starts at the minimum; this sits further out
    Camera_MinZoom = 10,
    Camera_MaxZoom = 20,
    Camera_HeightOffset = 1.5, -- raises the view over the shoulder line
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

function CameraController:Apply(character: Model)
    local player = Players.LocalPlayer
    if setting("Camera_ArenaFraming") ~= true then
        return
    end
    -- Min must be raised before Zoom, or the zoom value gets clamped to the old minimum.
    player.CameraMinZoomDistance = setting("Camera_MinZoom")
    player.CameraMaxZoomDistance = setting("Camera_MaxZoom")

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.CameraOffset = Vector3.new(0, setting("Camera_HeightOffset"), 0)
    end

    local cam = workspace.CurrentCamera
    if cam then
        -- nudge the actual distance out once; the player can still zoom within the range
        local subject = cam.CameraSubject
        if subject then
            cam.FieldOfView = 70
        end
    end
    player.CameraMode = Enum.CameraMode.Classic
end

function CameraController:KnitStart()
    local player = Players.LocalPlayer
    if player.Character then
        self:Apply(player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid", 5)
        self:Apply(character)
    end)

    -- live-tunable: changing the attributes in Studio re-applies without a respawn
    local t = tuning()
    if t then
        t.AttributeChanged:Connect(function(key)
            if key:sub(1, 7) == "Camera_" and player.Character then
                self:Apply(player.Character)
            end
        end)
    end
end

return CameraController
