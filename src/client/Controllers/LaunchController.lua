-- Launch pads apply velocity on the client, because the player's character is client-owned
-- and server-set velocity on it is unreliable. The server decides when and how far; we execute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local LaunchController = Knit.CreateController({ Name = "LaunchController" })

function LaunchController:KnitStart()
    Knit.GetService("PickupService").Launch:Connect(function(velocity, flightSeconds)
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not hum then
            return
        end
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        root.AssemblyLinearVelocity = velocity
        -- hold the launch velocity through the first frames so the humanoid does not damp it
        local t0 = os.clock()
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if os.clock() - t0 > 0.12 then
                conn:Disconnect()
                return
            end
            root.AssemblyLinearVelocity = velocity
        end)
        task.delay(math.max(0.3, flightSeconds - 0.2), function()
            if hum.Parent then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end)
    end)
end

return LaunchController
