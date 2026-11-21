-- Studio only: press P to circle the camera round your own character, to check a kit look or a
-- character skin from the front. The Weapons Kit holds the camera behind you while a gun is
-- out and the Server view does not frame a moving character, so neither showed the knight's
-- front. Press P again for the normal camera. Does nothing in a published game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local LookPreviewController = Knit.CreateController({ Name = "LookPreviewController" })

local DISTANCE = 11 -- studs from the character
local HEIGHT = 1.5 -- camera above the character's middle
local TURN_SPEED = 0.5 -- radians a second
local BIND = "LookPreviewOrbit"

function LookPreviewController:KnitStart()
    if not RunService:IsStudio() then
        return
    end
    local player = Players.LocalPlayer
    local active = false
    local angle = 0

    local function stop()
        active = false
        RunService:UnbindFromRenderStep(BIND)
        local camera = workspace.CurrentCamera
        if camera then
            camera.CameraType = Enum.CameraType.Custom
        end
    end

    local function start()
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local camera = workspace.CurrentCamera
        if not (root and camera) then
            return
        end
        -- A held gun makes the Weapons Kit twist the head and upper body toward the camera,
        -- which from the front turns them sideways. Put it away so the pose is neutral.
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:UnequipTools()
        end
        active = true
        angle = 0 -- start straight in front
        camera.CameraType = Enum.CameraType.Scriptable
        -- Last priority: after the Weapons Kit and the default camera have had their turn.
        RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value, function(dt)
            local now = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not now then
                stop()
                return
            end
            angle += dt * TURN_SPEED
            local front = now.CFrame.LookVector
            local around = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(front)
            local target = now.Position + Vector3.new(0, HEIGHT, 0)
            camera.CFrame = CFrame.lookAt(target + around * DISTANCE + Vector3.new(0, 1, 0), target)
        end)
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or input.KeyCode ~= Enum.KeyCode.P then
            return
        end
        if active then
            stop()
        else
            start()
        end
    end)
    player.CharacterRemoving:Connect(function()
        if active then
            stop()
        end
    end)
end

return LookPreviewController
