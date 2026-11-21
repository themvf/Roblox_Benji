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
    -- Vehicles: the view from the seat (VehicleController toggles it; see SetVehicleInside).
    Vehicle_InsideView = false, -- which view a player starts in the first time they board
    Vehicle_InsideFov = 80, -- wider than the 70 used on foot, so the bow and both sides stay in view
    Vehicle_InsideEyeHeight = 0, -- studs above the head; raise it if a dashboard blocks the view
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

-- The view from the seat. Roblox's own first-person mode does the work: it puts the camera
-- at the head, hides the player's own character, and already handles looking around by
-- mouse, touch drag and gamepad stick, so there is one behaviour on every device.
-- Arena framing forbids zooming in that far (Camera_MinZoom), so it is lifted while inside
-- and put back by Apply on the way out, which also pushes the camera back out behind.
-- `eyeOffset`, when given, puts the camera somewhere other than the head: a vehicle with no
-- cabin to look out of asks for a point over its bonnet. It is in the character's own frame.
function CameraController:SetVehicleInside(inside: boolean, eyeOffset: Vector3?)
    local player = Players.LocalPlayer
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera
    if inside then
        self.VehicleInside = true
        player.CameraMinZoomDistance = 0.5
        player.CameraMode = Enum.CameraMode.LockFirstPerson
        if eyeOffset ~= nil then
            self.VehicleEyeOffset = eyeOffset
        end
        if humanoid then
            local lift = Vector3.new(0, math.clamp(setting("Vehicle_InsideEyeHeight"), -2, 4), 0)
            humanoid.CameraOffset = (self.VehicleEyeOffset or Vector3.zero) + lift
        end
        if cam then
            cam.FieldOfView = math.clamp(setting("Vehicle_InsideFov"), 50, 100)
        end
        return
    end
    if not self.VehicleInside then
        return
    end
    self.VehicleInside = false
    self.VehicleEyeOffset = nil
    player.CameraMode = Enum.CameraMode.Classic
    if cam then
        cam.FieldOfView = 70
    end
    if setting("Camera_ArenaFraming") == true then
        if character then
            self:Apply(character)
        end
    else
        -- No arena framing to restore: undo what was changed and step the camera back out.
        if humanoid then
            humanoid.CameraOffset = Vector3.zero
        end
        player.CameraMinZoomDistance = 12.5
        task.delay(0.2, function()
            if not self.VehicleInside then
                player.CameraMinZoomDistance = 0.5
            end
        end)
    end
end

function CameraController:Apply(character: Model)
    local player = Players.LocalPlayer
    if self.VehicleInside then
        return -- the seat view owns the camera until the player leaves it
    end
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
            elseif key:sub(1, 14) == "Vehicle_Inside" and self.VehicleInside then
                self:SetVehicleInside(true) -- live-tune the seat view's field of view and eye height
            end
        end)
    end
end

return CameraController
