-- One action path for mouse, controller and touch while a player operates a map turret.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local TurretController = Knit.CreateController({ Name = "TurretController" })

local function button(name, label, color)
    local widget = Instance.new("TextButton")
    widget.Name = name
    widget.Text = label
    widget.TextColor3 = Theme.Color.Text
    widget.BackgroundColor3 = color
    widget.BackgroundTransparency = Theme.Transparency.Panel
    widget.Font = Enum.Font.GothamBold
    widget.TextSize = Theme.textSize(Theme.Type.Body)
    widget.AnchorPoint = Vector2.new(1, 0)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = widget
    return widget
end

function TurretController:KnitStart()
    local player = Players.LocalPlayer
    local service = Knit.GetService("TurretService")
    local gui = Screen.newScreenGui("TurretHud", Screen.Layers.Touch)
    gui.Parent = player:WaitForChild("PlayerGui")

    local ammo = Instance.new("TextLabel")
    ammo.Name = "TurretStatus"
    ammo.Size = UDim2.fromOffset(220, 56)
    ammo.AnchorPoint = Vector2.new(1, 0)
    ammo.BackgroundColor3 = Theme.Color.Panel
    ammo.BackgroundTransparency = Theme.Transparency.Panel
    ammo.TextColor3 = Theme.Color.Text
    ammo.Font = Enum.Font.GothamBold
    ammo.TextSize = Theme.textSize(Theme.Type.Body)
    ammo.Text = "TURRET  60 / 60"
    ammo.Visible = false
    ammo.Parent = gui
    Screen.autoScale(ammo)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = ammo

    local fire = button("TurretFire", "FIRE", Theme.Color.Danger)
    fire.Parent = gui
    fire.Visible = false
    local exit = button("TurretExit", "EXIT", Theme.Color.PanelHigh)
    exit.AnchorPoint = Vector2.new(0, 0)
    exit.Parent = gui
    exit.Visible = false

    Screen.onChange(function(state)
        ammo.Position = UDim2.new(1, -state.Insets.Right - 8, 0, state.Insets.Top + 10)
        fire.Size = UDim2.fromOffset(Screen.tapSize(76), Screen.tapSize(76))
        fire.Position = UDim2.new(1, -state.Insets.Right - 8, 0, state.Insets.Top + 90)
        exit.Size = UDim2.fromOffset(Screen.tapSize(64), Screen.tapSize(64))
        exit.Position = UDim2.new(0, state.Insets.Left + 8, 0, state.Insets.Top + 90)
        fire.Visible = self.Active ~= nil and state.Touch
        exit.Visible = self.Active ~= nil and state.Touch
        if self.Active then
            Screen.audit(fire, "Turret fire")
            Screen.audit(exit, "Turret exit")
        end
    end)

    local previousSubject = nil
    local lastAim = 0
    local lastFire = 0
    local firing = false
    local ammoConnection = nil
    local reloadConnection = nil

    local function updateAmmo()
        if not self.Active then
            return
        end
        local count = self.Active:GetAttribute("Ammo") or 0
        local reloadUntil = self.Active:GetAttribute("ReloadUntil")
        if reloadUntil and count == 0 then
            ammo.Text = "TURRET  RELOADING"
        else
            ammo.Text = ("TURRET  %d / %d"):format(count, self.Active:GetAttribute("Magazine") or 60)
        end
    end

    local function leaveLocal()
        firing = false
        self.Active = nil
        ammo.Visible = false
        fire.Visible = false
        exit.Visible = false
        if ammoConnection then
            ammoConnection:Disconnect()
            ammoConnection = nil
        end
        if reloadConnection then
            reloadConnection:Disconnect()
            reloadConnection = nil
        end
        local camera = workspace.CurrentCamera
        if camera and previousSubject then
            camera.CameraSubject = previousSubject
        end
        previousSubject = nil
    end

    service.Entered:Connect(function(model)
        leaveLocal()
        self.Active = model
        ammo.Visible = true
        fire.Visible = Screen.isTouch()
        exit.Visible = Screen.isTouch()
        ammoConnection = model:GetAttributeChangedSignal("Ammo"):Connect(updateAmmo)
        reloadConnection = model:GetAttributeChangedSignal("ReloadUntil"):Connect(updateAmmo)
        updateAmmo()
        local camera = workspace.CurrentCamera
        local head = model:FindFirstChild("Head")
        if camera and head and head.PrimaryPart then
            previousSubject = camera.CameraSubject
            camera.CameraSubject = head.PrimaryPart
        end
    end)
    service.Left:Connect(leaveLocal)

    local function requestExit()
        if self.Active then
            service:Exit()
            leaveLocal()
        end
    end

    fire.InputBegan:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            firing = true
        end
    end)
    fire.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            firing = false
        end
    end)
    exit.Activated:Connect(requestExit)
    UserInputService.InputBegan:Connect(function(input, processed)
        if not self.Active then
            return
        end
        if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonB then
            requestExit()
        elseif
            not processed
            and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2)
        then
            firing = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
            firing = false
        end
    end)
    UserInputService.WindowFocusReleased:Connect(function()
        firing = false
    end)
    player.CharacterAdded:Connect(function()
        if self.Active then
            requestExit()
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not self.Active then
            return
        end
        if not self.Active.Parent then
            leaveLocal()
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local direction = camera.CFrame.LookVector
        local now = os.clock()
        if now - lastAim >= 0.1 then
            lastAim = now
            service:Aim(direction)
        end
        if firing and now - lastFire >= 0.125 then
            lastFire = now
            service:Fire(direction)
        end
    end)
end

return TurretController
