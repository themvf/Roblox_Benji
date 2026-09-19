-- Jetpack flight: hold Jump while the Jetpack is equipped to burn fuel and rise.
-- Fuel drains while burning and recharges on the ground. Movement is client-driven,
-- like all Roblox character movement; the server mirrors the flame for other players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local JetpackController = Knit.CreateController({ Name = "JetpackController" })

JetpackController.Fuel = 0
JetpackController.MaxFuel = 0
JetpackController.Active = false -- true while a jetpack tool is equipped

local jumpHeld = false
local lastJumpRequest = 0 -- JumpRequest repeats every frame while the jump input is held
local thrusting = false
JetpackController.TouchHold = false -- set by the touch HUD's FLY button
local mover -- LinearVelocity while burning

local function equippedJetpack()
    local character = Players.LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    if tool and tool:GetAttribute("WeaponClass") == "Utility" and Weapons[tool.Name] then
        return tool, Weapons[tool.Name]
    end
    return nil
end

local function setThrusting(on)
    if thrusting == on then
        return
    end
    thrusting = on
    Knit.GetService("UtilityService"):SetThrusting(on)
end

local function stopMover()
    if mover then
        mover:Destroy()
        mover = nil
    end
end

function JetpackController:KnitStart()
    UserInputService.JumpRequest:Connect(function()
        jumpHeld = true
        lastJumpRequest = os.clock()
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
            jumpHeld = false
        end
    end)

    RunService.Heartbeat:Connect(function(dt)
        local tool, stats = equippedJetpack()
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChildOfClass("Humanoid")

        if not tool or not root or not hum or hum.Health <= 0 then
            self.Active = false
            setThrusting(false)
            stopMover()
            jumpHeld = jumpHeld and UserInputService:IsKeyDown(Enum.KeyCode.Space)
            return
        end

        local temporary = tool:GetAttribute("Temporary") == true
        if not self.Active or self.ActiveTool ~= tool then
            self.Active = true
            self.ActiveTool = tool
            if temporary then
                -- pickup jetpack: FuelSeconds of thrust, converted to fuel units at the burn rate
                self.MaxFuel = (tool:GetAttribute("FuelSeconds") or 3.5) * stats.Burn
                self.Fuel = self.MaxFuel
            else
                self.MaxFuel = stats.Fuel
                self.Fuel = self.Fuel > 0 and math.min(self.Fuel, stats.Fuel) or stats.Fuel
            end
        end

        -- Held = keyboard Space still down, or any jump input (touch jump button, gamepad A)
        -- requested within the last few frames, or the touch HUD's FLY button held.
        local holding = (jumpHeld and UserInputService:IsKeyDown(Enum.KeyCode.Space))
            or (os.clock() - lastJumpRequest < 0.12)
            or self.TouchHold
        local grounded = hum.FloorMaterial ~= Enum.Material.Air

        if holding and self.Fuel > 0 then
            self.Fuel = math.max(0, self.Fuel - stats.Burn * dt)
            if not mover then
                mover = Instance.new("LinearVelocity")
                mover.Name = "JetpackThrust"
                mover.MaxForce = math.huge
                mover.RelativeTo = Enum.ActuatorRelativeTo.World
                mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
                mover.LineDirection = Vector3.yAxis
                local att = root:FindFirstChild("RootAttachment")
                if not att then
                    att = Instance.new("Attachment")
                    att.Parent = root
                end
                mover.Attachment0 = att
                mover.Parent = root
            end
            -- rise quickly, then hold a gentler climb so it feels like a pack not a rocket
            mover.LineVelocity = stats.Thrust
            setThrusting(true)
        else
            stopMover()
            setThrusting(false)
            if grounded and not temporary then
                self.Fuel = math.min(stats.Fuel, self.Fuel + stats.Recharge * dt)
            elseif grounded and temporary and self.Fuel <= 0 then
                tool:Destroy() -- spent pickup jetpack
            end
        end
        tool:SetAttribute("Fuel", math.floor(self.Fuel))
    end)
end

return JetpackController
