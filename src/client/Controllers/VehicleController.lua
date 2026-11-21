-- Client vehicle driving/flying controller + cross-platform HUD/touch controls.
-- Never writes Humanoid.WalkSpeed (check_movement gate compliant).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local function heliFireCooldown()
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    local v = tuning and tuning:GetAttribute("HeliRocket_FireCooldown")
    if type(v) == "number" and v == v and v >= 0.1 and v <= 5 then
        return v
    end
    return Config.HeliRocket.FireCooldown
end

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
    banner.Size = UDim2.fromOffset(680, 44)
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

    local rocketPill = Instance.new("TextLabel")
    rocketPill.Name = "RocketStatus"
    rocketPill.Size = UDim2.fromOffset(210, 32)
    rocketPill.AnchorPoint = Vector2.new(0.5, 0)
    rocketPill.BackgroundColor3 = Theme.Color.Panel
    rocketPill.BackgroundTransparency = Theme.Transparency.Panel
    rocketPill.TextColor3 = Theme.Color.Accent
    rocketPill.Font = Enum.Font.GothamBold
    rocketPill.TextSize = Theme.textSize(Theme.Type.Label)
    rocketPill.Visible = false
    rocketPill.Parent = gui
    Screen.autoScale(rocketPill)
    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 8)
    pillCorner.Parent = rocketPill

    local upBtn = makeButton("HeliUp", "UP", Theme.Color.Fly)
    local downBtn = makeButton("HeliDown", "DOWN", Theme.Color.PanelHigh)
    local fireBtn = makeButton("HeliFire", "ROCKET", Theme.Color.Energy)
    local exitBtn = makeButton("VehicleExit", "EXIT", Theme.Color.Danger)
    local viewBtn = makeButton("VehicleView", "VIEW", Theme.Color.PanelHigh)
    viewBtn.Visible = false
    viewBtn.Parent = gui
    upBtn.Visible = false
    downBtn.Visible = false
    fireBtn.Visible = false
    exitBtn.Visible = false
    upBtn.Parent = gui
    downBtn.Parent = gui
    fireBtn.Parent = gui
    exitBtn.Parent = gui

    local activeModel: Model? = nil
    local activeRole: string? = nil
    local activeType: string? = nil
    local touchUp = false
    local touchDown = false
    local fireHeld = false
    local lastRocketAt = 0
    local yawAngle = 0
    local jumpLocked = false
    local heliVel = Vector3.zero
    local heliVy = 0
    local heliYawVel = 0
    local heliPitch = 0
    local heliRoll = 0
    local hoverClock = 0
    local buggyVel = Vector3.zero
    local buggyVy = 0
    local buggyPitch = 0
    local buggyRoll = 0
    local boatVel = Vector3.zero
    local boatYawVel = 0
    local handling = nil -- Config.VehicleHandling for the vehicle being driven, Tuning applied

    -- Two views while seated: the chase view (the normal camera behind the vehicle) and the
    -- view from the seat. The choice is remembered for the next vehicle. V, D-pad up, or the
    -- VIEW button on touch.
    local cameraController = Knit.GetController("CameraController")
    local tuningFolder = ReplicatedStorage:FindFirstChild("Tuning")
    local insideView = tuningFolder ~= nil and tuningFolder:GetAttribute("Vehicle_InsideView") == true

    local function applyView()
        local model = activeModel
        local inside = model ~= nil and insideView
        local eye = model and model:GetAttribute("InsideEye")
        cameraController:SetVehicleInside(inside)
        if inside and typeof(eye) == "Vector3" then
            -- No cabin to look out of: the camera goes over the bonnet instead, on the sitter's
            -- own side. Worked out a moment after sitting, once the seat has placed the character.
            task.delay(0.25, function()
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and char:FindFirstChild("Head")
                local root = model.PrimaryPart
                if activeModel ~= model or not insideView or not (hrp and head and root) then
                    return
                end
                local side = activeRole == "Passenger" and -1 or 1
                local point = root.CFrame:PointToWorldSpace(eye * Vector3.new(side, 1, 1))
                cameraController:SetVehicleInside(true, hrp.CFrame:VectorToObjectSpace(point - head.Position))
            end)
        end
        viewBtn.Text = insideView and "CHASE" or "INSIDE" -- names the view a tap switches to
    end

    if tuningFolder then
        tuningFolder.AttributeChanged:Connect(function(key)
            if activeType and key:sub(1, 9) == "Handling_" then
                handling = Config.GetHandling(activeType, tuningFolder) or handling
            end
        end)
    end

    local function toggleView()
        if activeModel then
            insideView = not insideView
            applyView()
        end
    end

    local function layoutHud(state)
        banner.Position = UDim2.new(0.5, 0, 0, state.Insets.Top + 10)
        rocketPill.Position = UDim2.new(0.5, 0, 0, state.Insets.Top + 60)
        local tap = Screen.tapSize(68)
        exitBtn.Size = UDim2.fromOffset(tap, tap)
        exitBtn.Position = UDim2.new(1, -state.Insets.Right - 10, 1, -state.Insets.Bottom - 16)
        upBtn.Size = UDim2.fromOffset(tap, tap)
        upBtn.Position = UDim2.new(1, -state.Insets.Right - 10, 1, -state.Insets.Bottom - 16 - tap - 10)
        downBtn.Size = UDim2.fromOffset(tap, tap)
        downBtn.Position = UDim2.new(1, -state.Insets.Right - 10 - tap - 10, 1, -state.Insets.Bottom - 16)
        fireBtn.Size = UDim2.fromOffset(tap, tap)
        fireBtn.Position = UDim2.new(1, -state.Insets.Right - 10 - tap - 10, 1, -state.Insets.Bottom - 16 - tap - 10)

        local showTouch = activeModel ~= nil and state.Touch
        local isHeliPilot = showTouch and activeRole == "Driver" and activeType == "Helicopter"
        -- VIEW sits directly above EXIT; a helicopter pilot's UP button has that slot, so it goes one higher.
        local viewRow = isHeliPilot and 2 or 1
        viewBtn.Size = UDim2.fromOffset(tap, tap)
        viewBtn.Position = UDim2.new(1, -state.Insets.Right - 10, 1, -state.Insets.Bottom - 16 - (tap + 10) * viewRow)
        viewBtn.Visible = showTouch
        exitBtn.Visible = showTouch
        upBtn.Visible = isHeliPilot
        downBtn.Visible = isHeliPilot
        fireBtn.Visible = isHeliPilot
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
                banner.Text = "ARMY RHIB PASSENGER · Weapons Active · V View · Space Exit"
            elseif activeType == "ArmoredVehicle" then
                banner.Text = "ARMORED VEHICLE PASSENGER · Weapons Active · V View · Space Exit"
            elseif activeType == "SUV" then
                banner.Text = "SUV PASSENGER · Weapons Active · V View · Space Exit"
            elseif activeType == "Buggy" then
                banner.Text = "BUGGY PASSENGER · Weapons Active · V View · Space Exit"
            else
                banner.Text = "HELICOPTER PASSENGER · Transport Only · V View · Space Exit"
            end
        elseif activeType == "Helicopter" then
            banner.Text =
                "HELICOPTER · W/S Fly · A/D Turn · Space Up · Ctrl/C Down · Click/F Rocket · R Reload · V View · E Exit"
        elseif activeType == "SUV" then
            banner.Text = "SUV · W/S/A/D Drive · V View · Space Exit"
        elseif activeType == "ArmoredVehicle" then
            banner.Text = "ARMORED VEHICLE · W/S/A/D Drive · V View · Space Exit"
        elseif activeType == "Buggy" then
            banner.Text = "COMBAT BUGGY · W/S/A/D Drive · Shift Boost · V View · Space Exit"
        elseif activeType == "RHIB" then
            banner.Text = "BLACK ARMY RHIB · W/S/A/D Drive · V View · Space Exit"
        else
            banner.Text = "WAVE RUNNER · W/S/A/D Ride · V View · Space Exit"
        end
    end

    local function resetFlightState(root)
        heliVel = Vector3.zero
        heliVy = 0
        heliYawVel = 0
        heliPitch = 0
        heliRoll = 0
        hoverClock = 0
        buggyVel = Vector3.zero
        buggyVy = 0
        buggyPitch = 0
        buggyRoll = 0
        boatVel = Vector3.zero
        boatYawVel = 0
        if root then
            boatVel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            local v = root.AssemblyLinearVelocity
            heliVel = Vector3.new(v.X, 0, v.Z)
            heliVy = v.Y
            buggyVel = Vector3.new(v.X, 0, v.Z)
            buggyVy = v.Y
        end
    end

    local function clearActive()
        touchUp = false
        touchDown = false
        fireHeld = false
        activeModel = nil
        activeRole = nil
        activeType = nil
        resetFlightState(nil)
        setJumpLock(false)
        banner.Visible = false
        rocketPill.Visible = false
        upBtn.Visible = false
        downBtn.Visible = false
        fireBtn.Visible = false
        exitBtn.Visible = false
        viewBtn.Visible = false
        applyView()
    end

    service.VehicleStateChanged:Connect(function(model, role)
        if not model then
            clearActive()
            return
        end
        activeModel = model
        activeRole = role
        activeType = model:GetAttribute("VehicleType")
        -- A vehicle with no profile of its own drives like the nearest thing that has one.
        handling = Config.GetHandling(activeType, tuningFolder)
            or Config.GetHandling(Config.VehicleClass[activeType] == "Car" and "Buggy" or "RHIB", tuningFolder)
        local root = model.PrimaryPart
        if root then
            local look = root.CFrame.LookVector
            yawAngle = math.atan2(-look.X, -look.Z)
        end
        resetFlightState(root)
        -- Disable Space-to-jump while piloting Helicopter so Space can serve as Ascend cleanly
        setJumpLock(role == "Driver" and activeType == "Helicopter")
        refreshBanner()
        applyView()
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
    local function getRocketAimDir(root)
        local cam = workspace.CurrentCamera
        local heliLook = root.CFrame.LookVector
        if not cam then
            return heliLook
        end
        local camCF = cam.CFrame
        local exclude = { activeModel }
        if player.Character then
            table.insert(exclude, player.Character)
        end
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = exclude
        local hit = workspace:Raycast(camCF.Position, camCF.LookVector * 650, rayParams)
        local aimPoint = hit and hit.Position or (camCF.Position + camCF.LookVector * 650)
        local muzzleCenter = root.Position + heliLook * 6
        local delta = aimPoint - muzzleCenter
        if delta.Magnitude < 1 then
            return heliLook
        end
        local dir = delta.Unit
        if dir:Dot(heliLook) < 0.25 then
            return heliLook
        end
        return dir
    end

    local function refreshRocketHud()
        if not activeModel or activeType ~= "Helicopter" or activeRole ~= "Driver" then
            rocketPill.Visible = false
            return
        end
        rocketPill.Visible = true
        local cap = activeModel:GetAttribute("RocketCapacity") or Config.HeliRocket.AmmoCapacity
        local ammo = activeModel:GetAttribute("RocketAmmo") or cap
        local reloadEnds = activeModel:GetAttribute("RocketReloadEndsAt") or 0
        local remaining = reloadEnds - workspace:GetServerTimeNow()
        if remaining > 0.05 then
            rocketPill.Text = ("RELOADING  %.1fs"):format(remaining)
            rocketPill.TextColor3 = Theme.Color.Energy
        else
            rocketPill.Text = ("ROCKETS  %d / %d"):format(ammo, cap)
            rocketPill.TextColor3 = ammo > 0 and Theme.Color.Accent or Theme.Color.Energy
        end
    end

    local function tryFireRocket()
        if not activeModel or not activeModel.Parent or activeRole ~= "Driver" or activeType ~= "Helicopter" then
            return
        end
        local reloadEnds = activeModel:GetAttribute("RocketReloadEndsAt") or 0
        if reloadEnds > workspace:GetServerTimeNow() then
            return
        end
        local now = os.clock()
        if now - lastRocketAt < heliFireCooldown() then
            return
        end
        local root = activeModel.PrimaryPart
        if not root then
            return
        end
        lastRocketAt = now
        local dir = getRocketAimDir(root)
        task.spawn(function()
            service:FireRocket(dir)
        end)
    end

    fireBtn.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            fireHeld = true
            tryFireRocket()
        end
    end)
    fireBtn.InputEnded:Connect(function()
        fireHeld = false
    end)
    exitBtn.Activated:Connect(function()
        if activeModel then
            service:RequestExit()
        end
    end)
    viewBtn.Activated:Connect(toggleView)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not activeModel then
            return
        end
        if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.DPadUp then
            toggleView()
            return
        end
        if activeRole == "Driver" and activeType == "Helicopter" then
            if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonB then
                service:RequestExit()
            elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then
                task.spawn(function()
                    service:ReloadRockets()
                end)
            elseif
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.KeyCode == Enum.KeyCode.F
                or input.KeyCode == Enum.KeyCode.ButtonR2
            then
                fireHeld = true
                tryFireRocket()
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.KeyCode == Enum.KeyCode.F
            or input.KeyCode == Enum.KeyCode.ButtonR2
        then
            fireHeld = false
        end
    end)
    UserInputService.WindowFocusReleased:Connect(function()
        fireHeld = false
    end)

    player.CharacterAdded:Connect(function()
        clearActive()
    end)

    local rotorSpin = 0
    -- SUV wheels are separate parts on Welds; each client turns them from the car's own speed.
    local SUV_WHEEL_RADIUS = 1.65
    local wheelAngle = setmetatable({}, { __mode = "k" })
    local wheelRest = setmetatable({}, { __mode = "k" })
    RunService.RenderStepped:Connect(function(dt)
        -- Visual rotor spin on any active helicopter in the arena
        rotorSpin += dt * 18
        local mapFolder = workspace:FindFirstChild("Map")
        local vehiclesFolder = mapFolder and mapFolder:FindFirstChild("Vehicles")
        if vehiclesFolder then
            for _, m in vehiclesFolder:GetChildren() do
                local chassis = Config.VehicleClass[m:GetAttribute("VehicleType")] == "Car" and m.PrimaryPart or nil
                if chassis then
                    local speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
                    local angle = (wheelAngle[m] or 0) + speed / SUV_WHEEL_RADIUS * dt
                    wheelAngle[m] = angle
                    for _, weld in chassis:GetChildren() do
                        if weld.Name == "WheelWeld" and weld:IsA("Weld") then
                            local rest = wheelRest[weld]
                            if not rest then
                                rest = weld.C0
                                wheelRest[weld] = rest
                            end
                            -- Forward is -Z, so the top of the wheel rolls toward -Z: a negative turn about X.
                            weld.C0 = CFrame.new(rest.Position) * CFrame.Angles(-angle, 0, 0) * rest.Rotation
                        end
                    end
                end
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

        if activeType == "Helicopter" then
            -- Never let VehicleSeat jump-eject while Space acts as collective Climb
            if hum.Jump then
                hum.Jump = false
            end
            refreshRocketHud()
            if fireHeld then
                tryFireRocket()
            end

            hoverClock += dt
            local yawRateTarget = steer * turnSpeed
            heliYawVel += (yawRateTarget - heliYawVel) * (1 - math.exp(-7.5 * dt))
            yawAngle += heliYawVel * dt

            local forward = Vector3.new(-math.sin(yawAngle), 0, -math.cos(yawAngle))
            local right = Vector3.new(math.cos(yawAngle), 0, -math.sin(yawAngle))

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

            -- Ground/water clearance beneath the fuselage floor (~1.8 studs above skids)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { activeModel, char }
            local groundHit = workspace:Raycast(root.Position, Vector3.new(0, -40, 0), rayParams)
            local groundY = groundHit and math.max(groundHit.Position.Y, 0) or 0
            local skidClearance = math.max(0, root.Position.Y - groundY - 1.8)
            local airAuthority = math.clamp(skidClearance / 1.25, 0, 1)

            -- Collective vertical velocity with smooth spool inertia & low-hover takeoff cushion
            local targetVy = 0
            if climb > 0 then
                targetVy = 46
            elseif climb < 0 then
                targetVy = skidClearance < 0.6 and -12 or -38
            elseif math.abs(throttle) > 0.1 and skidClearance < 5.5 then
                -- Pressing W/S on the pad lifts smoothly into a hover instead of driving like a car
                targetVy = 24 * (1 - skidClearance / 5.5)
            elseif skidClearance >= 0.7 then
                targetVy = math.sin(hoverClock * 2.2) * 0.45
            else
                targetVy = -2.0
            end
            local vyRate = climb ~= 0 and 5.2 or 3.6
            heliVy += (targetVy - heliVy) * (1 - math.exp(-vyRate * dt))
            if root.Position.Y >= 200 and heliVy > 0 then
                heliVy = 0
            end

            -- World-space horizontal flight momentum: cyclic acceleration, banked-turn drift, air drag
            local desiredHoriz = Vector3.zero
            local horizRate = 8.0
            if airAuthority > 0.2 then
                if math.abs(throttle) > 0.05 then
                    local targetSpeed = throttle >= 0 and (throttle * maxSpeed) or (throttle * maxSpeed * 0.4)
                    desiredHoriz = forward * targetSpeed
                    horizRate = 2.5
                else
                    horizRate = 1.05 -- aerodynamic drag lets the Black Hawk coast and flare instead of braking dead
                end
            end
            heliVel = heliVel:Lerp(desiredHoriz, 1 - math.exp(-horizRate * dt))

            lv.VectorVelocity = Vector3.new(heliVel.X, heliVy, heliVel.Z)
            av.AngularVelocity = Vector3.zero

            -- Helicopter pitch (nose-down acceleration / nose-up flare) and banked roll into turns
            local fwdSpeed = heliVel:Dot(forward)
            local sideSpeed = heliVel:Dot(right)
            local speedNorm = math.clamp(math.abs(fwdSpeed) / maxSpeed, 0, 1)
            local targetPitch = math.clamp(
                (-throttle * math.rad(20) - (fwdSpeed / maxSpeed) * math.rad(9)) * airAuthority,
                math.rad(-28),
                math.rad(22)
            )
            local targetRoll = math.clamp(
                (
                    steer * math.rad(26) * (0.45 + 0.55 * speedNorm)
                    + math.clamp(sideSpeed / maxSpeed, -1, 1) * math.rad(10)
                ) * airAuthority,
                math.rad(-32),
                math.rad(32)
            )
            local attAlpha = 1 - math.exp(-6.5 * dt)
            heliPitch += (targetPitch - heliPitch) * attAlpha
            heliRoll += (targetRoll - heliRoll) * attAlpha

            ao.CFrame = CFrame.new(root.Position)
                * CFrame.Angles(0, yawAngle, 0)
                * CFrame.Angles(heliPitch, 0, heliRoll)
        elseif Config.VehicleClass[activeType] == "Car" and handling then
            local h = handling
            local boosting = h.Boost > 1
                and (
                    UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                    or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                )
            local effMaxSpeed = boosting and (maxSpeed * h.Boost) or maxSpeed

            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { activeModel, char }
            local ground = workspace:Raycast(root.Position + Vector3.new(0, 1.0, 0), Vector3.new(0, -3.6, 0), rayParams)
            local grounded = ground ~= nil and not (buggyVy > 18 and root.Position.Y > ground.Position.Y + 2.3)

            -- A car steers by rolling: no steering when stopped, less at speed, and backwards
            -- when reversing.
            local forward = Vector3.new(-math.sin(yawAngle), 0, -math.cos(yawAngle))
            local rolling = buggyVel:Dot(forward)
            local authority = h.TurnFullSpeed > 0 and math.clamp(math.abs(rolling) / h.TurnFullSpeed, 0, 1) or 1
            local fade = 1 - (1 - h.HighSpeedTurn) * math.clamp(math.abs(rolling) / maxSpeed, 0, 1)
            local direction = rolling < -1 and -1 or 1
            local steerScale = grounded and 1.0 or 0.25
            yawAngle += steer * turnSpeed * steerScale * authority * fade * direction * dt
            forward = Vector3.new(-math.sin(yawAngle), 0, -math.cos(yawAngle))

            if grounded then
                -- Speed along the car closes on the pedal at the car's own rate; whatever is
                -- left sideways after a turn dies off with its grip.
                local along = buggyVel:Dot(forward)
                local target = throttle >= 0 and throttle * effMaxSpeed or throttle * maxSpeed * h.Reverse
                local rate = h.Accel
                if math.abs(throttle) < 0.05 then
                    rate = h.Coast
                elseif throttle * along < 0 and math.abs(along) > 2 then
                    rate = h.Brake
                end
                local newSpeed = along + (target - along) * (1 - math.exp(-rate * dt))
                local slide = (buggyVel - forward * along) * math.exp(-h.Grip * dt)
                buggyVel = forward * newSpeed + slide

                local targetY = ground.Position.Y + 1.8
                local slopeSin = math.clamp(-forward:Dot(ground.Normal), -0.68, 0.68)
                local slopePitch = math.asin(slopeSin)
                local slopeVy = buggyVel:Dot(forward) * math.tan(slopePitch)
                local heightCorrection = (targetY - root.Position.Y) * 14
                buggyVy = math.clamp(slopeVy + heightCorrection, -65, 75)

                -- Squat under power, dive under brakes, lean in a turn.
                local squat = math.clamp((target - along) / maxSpeed, -1, 1) * math.rad(h.Pitch)
                local targetRoll = steer * math.rad(h.Roll) * math.clamp(buggyVel.Magnitude / maxSpeed, 0, 1)
                local attAlpha = 1 - math.exp(-10 * dt)
                buggyPitch += (slopePitch + squat - buggyPitch) * attAlpha
                buggyRoll += (targetRoll - buggyRoll) * attAlpha
            else
                -- Airborne off a ramp: preserve launch momentum and arc under arcade gravity
                buggyVel = buggyVel:Lerp(Vector3.zero, 1 - math.exp(-0.22 * dt))
                buggyVy = math.max(buggyVy - 110 * dt, -140)
                local airPitch = math.clamp(
                    math.atan2(buggyVy, math.max(buggyVel.Magnitude, 20)) * 0.65,
                    math.rad(-30),
                    math.rad(30)
                )
                local attAlpha = 1 - math.exp(-6 * dt)
                buggyPitch += (airPitch - buggyPitch) * attAlpha
                buggyRoll += (0 - buggyRoll) * attAlpha
            end

            lv.VectorVelocity = Vector3.new(buggyVel.X, buggyVy, buggyVel.Z)
            av.AngularVelocity = Vector3.zero
            ao.CFrame = CFrame.new(root.Position)
                * CFrame.Angles(0, yawAngle, 0)
                * CFrame.Angles(buggyPitch, 0, buggyRoll)
        elseif handling then
            -- Boats. A rudder only bites when water is moving past it, the turn builds and dies
            -- with a lag, and the hull keeps sliding the way it was going: it carries wide.
            local h = handling
            local forward = Vector3.new(-math.sin(yawAngle), 0, -math.cos(yawAngle))
            local way = boatVel:Dot(forward)
            local authority = math.max(h.TurnMin, math.clamp(math.abs(way) / math.max(h.TurnFullSpeed, 1), 0, 1))
            local direction = way < -1 and -1 or 1
            local yawTarget = steer * turnSpeed * authority * direction
            boatYawVel += (yawTarget - boatYawVel) * (1 - math.exp(-h.YawResponse * dt))
            yawAngle += boatYawVel * dt
            forward = Vector3.new(-math.sin(yawAngle), 0, -math.cos(yawAngle))

            -- Glide over the Terrain sea (Y = 0) and ramp gently onto shallow beaches
            local targetY = 0.35
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { activeModel, char }
            local ground = workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, -4.0, 0), rayParams)
            if ground and ground.Position.Y > 0.1 then
                targetY = ground.Position.Y + 0.55
            end
            local vy = math.clamp((targetY - root.Position.Y) * 10 - root.AssemblyLinearVelocity.Y * 1.8, -22, 22)

            -- No brakes: the throttle pulls speed toward the lever, and letting go coasts.
            local along = boatVel:Dot(forward)
            local target = throttle >= 0 and throttle * maxSpeed or throttle * maxSpeed * h.Reverse
            local rate = math.abs(throttle) > 0.05 and h.Accel or h.Coast
            local newSpeed = along + (target - along) * (1 - math.exp(-rate * dt))
            local slide = (boatVel - forward * along) * math.exp(-h.Grip * dt)
            boatVel = forward * newSpeed + slide
            lv.VectorVelocity = Vector3.new(boatVel.X, vy, boatVel.Z)
            av.AngularVelocity = Vector3.zero

            -- Lean into the turn in proportion to how hard it is actually turning, and lift
            -- the bow with speed.
            local turning = math.clamp(boatYawVel / math.max(turnSpeed, 0.1), -1, 1)
            local bank = turning * math.rad(h.Bank) * math.clamp(math.abs(newSpeed) / maxSpeed * 1.5, 0, 1)
            local pitch = math.clamp(newSpeed / maxSpeed, -0.5, 1) * math.rad(h.Pitch)
            ao.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yawAngle, 0) * CFrame.Angles(pitch, 0, bank)
        end
    end)
end

return VehicleController
