-- Client vehicle driving/flying controller + cross-platform HUD/touch controls.
-- Never writes Humanoid.WalkSpeed (check_movement gate compliant).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local VehicleController = Knit.CreateController({ Name = "VehicleController" })

local function makeButton(name, label, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Text = label
    btn.TextColor3 = Theme.Color.Text
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = Theme.Transparency.Panel
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = Theme.textSize(Theme.Type.Body)
    btn.AnchorPoint = Vector2.new(1, 1)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = btn
    return btn
end

function VehicleController:KnitStart()
    local player = Players.LocalPlayer
    local service = Knit.GetService("VehicleService")

    local gui = Screen.newScreenGui("VehicleHud", Screen.Layers.Touch)
    gui.Parent = player:WaitForChild("PlayerGui")

    local banner = Instance.new("TextLabel")
    banner.Name = "VehicleBanner"
    banner.Size = UDim2.fromOffset(420, 44)
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.BackgroundColor3 = Theme.Color.Panel
    banner.BackgroundTransparency = Theme.Transparency.Panel
    banner.TextColor3 = Theme.Color.Text
    banner.Font = Enum.Font.GothamBold
    banner.TextSize = Theme.textSize(Theme.Type.Label)
    banner.Visible = false
    banner.Parent = gui
    Screen.autoScale(banner)
    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 10)
    bannerCorner.Parent = banner

    local upBtn = makeButton("HeliUp", "UP", Theme.Color.Fly)
    local downBtn = makeButton("HeliDown", "DOWN", Theme.Color.PanelHigh)
    local exitBtn = makeButton("VehicleExit", "EXIT", Theme.Color.Danger)
    upBtn.Visible = false
    downBtn.Visible = false
    exitBtn.Visible = false
    upBtn.Parent = gui
    downBtn.Parent = gui
    exitBtn.Parent = gui

    local activeModel: Model? = nil
    local activeRole: string? = nil
    local activeType: string? = nil
    local touchUp = false
    local touchDown = false
    local yawAngle = 0
    local jumpLocked = false

    local function layoutHud(state)
        banner.Position = UDim2.new(0.5, 0, 0, state.Insets.Top + 10)
        local tap = Screen.tapSize(68)
        exitBtn.Size = UDim2.fromOffset(tap, tap)
        exitBtn.Position = UDim2.new(1, -state.Insets.Right - 10, 1, -state.Insets.Bottom - 16)
        upBtn.Size = UDim2.fromOffset(tap, tap)
        upBtn.Position = UDim2.new(1, -state.Insets.Right - 10, 1, -state.Insets.Bottom - 16 - tap - 10)
        downBtn.Size = UDim2.fromOffset(tap, tap)
        downBtn.Position = UDim2.new(1, -state.Insets.Right - 10 - tap - 10, 1, -state.Insets.Bottom - 16)

        local showTouch = activeModel ~= nil and state.Touch
        local isHeliPilot = showTouch and activeRole == "Driver" and activeType == "Helicopter"
        exitBtn.Visible = showTouch
        upBtn.Visible = isHeliPilot
        downBtn.Visible = isHeliPilot
    end

    Screen.onChange(layoutHud)

    local function setJumpLock(locked)
        if jumpLocked == locked then
            return
        end
        jumpLocked = locked
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not locked)
        end
    end

    local function refreshBanner()
        if not activeModel then
            banner.Visible = false
            return
        end
        banner.Visible = true
        if activeRole == "Passenger" then
            if activeType == "RHIB" then
                banner.Text = "ARMY RHIB PASSENGER · Weapons Active · Space Exit"
            else
                banner.Text = "HELICOPTER PASSENGER · Transport Only · Space Exit"
            end
        elseif activeType == "Helicopter" then
            banner.Text = "HELICOPTER · W/S Fly · A/D Turn · Space Up · Ctrl/C Down · E Exit"
        elseif activeType == "RHIB" then
            banner.Text = "BLACK ARMY RHIB · W/S/A/D Drive · Space Exit"
        else
            banner.Text = "WAVE RUNNER · W/S/A/D Ride · Space Exit"
        end
    end

    local function clearActive()
        touchUp = false
        touchDown = false
        activeModel = nil
        activeRole = nil
        activeType = nil
        setJumpLock(false)
        banner.Visible = false
        upBtn.Visible = false
        downBtn.Visible = false
        exitBtn.Visible = false
    end

    service.VehicleStateChanged:Connect(function(model, role)
        if not model then
            clearActive()
            return
        end
        activeModel = model
        activeRole = role
        activeType = model:GetAttribute("VehicleType")
        local root = model.PrimaryPart
        if root then
            local look = root.CFrame.LookVector
            yawAngle = math.atan2(-look.X, -look.Z)
        end
        -- Disable Space-to-jump while piloting Helicopter so Space can serve as Ascend cleanly
        setJumpLock(role == "Driver" and activeType == "Helicopter")
        refreshBanner()
        layoutHud(Screen.get())
    end)

    upBtn.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            touchUp = true
        end
    end)
    upBtn.InputEnded:Connect(function()
        touchUp = false
    end)
    downBtn.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            touchDown = true
        end
    end)
    downBtn.InputEnded:Connect(function()
        touchDown = false
    end)
    exitBtn.Activated:Connect(function()
        if activeModel then
            service:RequestExit()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not activeModel then
            return
        end
        if activeRole == "Driver" and activeType == "Helicopter" then
            if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonB then
                service:RequestExit()
            end
        end
    end)

    player.CharacterAdded:Connect(function()
        clearActive()
    end)

    local rotorSpin = 0
    RunService.RenderStepped:Connect(function(dt)
        -- Visual rotor spin on any active helicopter in the arena
        rotorSpin += dt * 18
        local mapFolder = workspace:FindFirstChild("Map")
        local vehiclesFolder = mapFolder and mapFolder:FindFirstChild("Vehicles")
        if vehiclesFolder then
            for _, m in vehiclesFolder:GetChildren() do
                if m:GetAttribute("VehicleType") == "Helicopter" and m:GetAttribute("ActivePilot") then
                    local mast = m:FindFirstChild("RotorMast")
                    local weld = mast and mast:FindFirstChild("RotorWeld")
                    if weld and weld:IsA("Weld") then
                        weld.C1 = CFrame.Angles(0, rotorSpin, 0)
                    end
                end
            end
        end

        if not activeModel or not activeModel.Parent or activeRole ~= "Driver" then
            return
        end
        local root = activeModel.PrimaryPart
        if not root then
            return
        end
        local lv = root:FindFirstChild("DriveVelocity")
        local av = root:FindFirstChild("DriveTurn")
        local ao = root:FindFirstChild("LevelAlign")
        if not lv or not av or not ao then
            return
        end

        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if not seat or not seat:IsA("VehicleSeat") then
            return
        end

        local maxSpeed = activeModel:GetAttribute("MaxSpeed") or 50
        local turnSpeed = activeModel:GetAttribute("TurnSpeed") or 2.0
        local throttle = seat.ThrottleFloat
        local steer = -seat.SteerFloat

        yawAngle += steer * turnSpeed * dt
        local forward = Vector3.new(-math.sin(yawAngle), 0, -math.cos(yawAngle))

        if activeType == "Helicopter" then
            local climb = 0
            if
                UserInputService:IsKeyDown(Enum.KeyCode.Space)
                or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA)
                or touchUp
            then
                climb += 1
            end
            if
                UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.C)
                or UserInputService:IsKeyDown(Enum.KeyCode.ButtonX)
                or touchDown
            then
                climb -= 1
            end
            local vy = climb * 44
            if root.Position.Y >= 200 and vy > 0 then
                vy = 0
            end
            local horizVel = forward * (throttle * maxSpeed)
            lv.VectorVelocity = Vector3.new(horizVel.X, vy, horizVel.Z)
            av.AngularVelocity = Vector3.zero
            local pitch = -throttle * math.rad(12)
            local roll = steer * math.rad(10)
            ao.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yawAngle, 0) * CFrame.Angles(pitch, 0, roll)
        else
            -- WaveRunner & RHIB: glide over Terrain sea (Y = 0) and ramp gently onto shallow beaches
            local targetY = 0.35
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { activeModel, char }
            local ground = workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, -4.0, 0), rayParams)
            if ground and ground.Position.Y > 0.1 then
                targetY = ground.Position.Y + 0.55
            end
            local vy = math.clamp((targetY - root.Position.Y) * 10 - root.AssemblyLinearVelocity.Y * 1.8, -22, 22)
            local horizVel = forward * (throttle * maxSpeed)
            lv.VectorVelocity = Vector3.new(horizVel.X, vy, horizVel.Z)
            av.AngularVelocity = Vector3.zero
            local bank = steer * math.rad(activeType == "WaveRunner" and 12 or 6)
            local pitch = throttle * math.rad(activeType == "WaveRunner" and 4 or 2)
            ao.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yawAngle, 0) * CFrame.Angles(pitch, 0, bank)
        end
    end)
end

return VehicleController
