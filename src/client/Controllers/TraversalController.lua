-- Executes server-authorized contextual traversal on the client-owned character.
-- The server validates the route and endpoint; the client supplies reliable character velocity.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local TraversalController = Knit.CreateController({ Name = "TraversalController" })

function TraversalController:Stop(outcome)
    local active = self.Active
    if not active then
        return
    end
    self.Active = nil
    if active.Connection then
        active.Connection:Disconnect()
    end
    if active.DiedConnection then
        active.DiedConnection:Disconnect()
    end
    if active.Humanoid and active.Humanoid.Parent then
        active.Humanoid.AutoRotate = true
        active.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    end
    if active.Root and active.Root.Parent and outcome ~= "Landed" then
        active.Root.AssemblyLinearVelocity *= Vector3.new(0.25, 0.25, 0.25)
    end
    if outcome then
        Knit.GetService("TraversalService"):Complete(active.Id, outcome)
    end
end

function TraversalController:Begin(routeId, target, speed, timeout, kind)
    self:Stop("Canceled")
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return
    end

    local active = {
        Id = routeId,
        Root = root,
        Humanoid = humanoid,
        Target = target,
        Speed = speed,
        StartedAt = os.clock(),
        Timeout = timeout,
        Kind = kind,
    }
    self.Active = active
    humanoid.AutoRotate = false
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    active.DiedConnection = humanoid.Died:Connect(function()
        self:Stop("Canceled")
    end)
    active.Connection = RunService.Heartbeat:Connect(function()
        if self.Active ~= active or not root.Parent or humanoid.Health <= 0 then
            self:Stop("Canceled")
            return
        end
        local delta = target - root.Position
        if delta.Magnitude <= 4 then
            root.AssemblyLinearVelocity = Vector3.zero
            self:Stop("Landed")
            return
        end
        if os.clock() - active.StartedAt >= timeout then
            self:Stop("Canceled")
            return
        end
        root.AssemblyLinearVelocity = delta.Unit * speed
        local flat = Vector3.new(delta.X, 0, delta.Z)
        if flat.Magnitude > 0.1 then
            root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
        end
    end)
end

function TraversalController:KnitStart()
    local service = Knit.GetService("TraversalService")
    service.Travel:Connect(function(routeId, target, speed, timeout, kind)
        self:Begin(routeId, target, speed, timeout, kind)
    end)
    service.Cancel:Connect(function(routeId)
        if self.Active and self.Active.Id == routeId then
            self:Stop(nil)
        end
    end)
end

return TraversalController
