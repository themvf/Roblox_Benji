-- Handles input, ammo, and reload timing, then asks the server to validate the shot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local WeaponController = Knit.CreateController({ Name = "WeaponController" })

WeaponController.Current = "AssaultRifle"
WeaponController.Ammo = Weapons.AssaultRifle.MagSize
WeaponController.Reloading = false
local lastShot = 0

function WeaponController:Fire()
    local stats = Weapons[self.Current]
    if self.Reloading or self.Ammo <= 0 then
        return
    end
    if os.clock() - lastShot < stats.FireRate then
        return
    end
    lastShot = os.clock()
    self.Ammo -= 1

    local cam = workspace.CurrentCamera
    local WeaponService = Knit.GetService("WeaponService")
    WeaponService:Fire(self.Current, cam.CFrame.Position, cam.CFrame.LookVector)
    if self.Ammo == 0 then
        self:Reload()
    end
end

function WeaponController:Reload()
    if self.Reloading then
        return
    end
    self.Reloading = true
    local weapon = self.Current
    task.delay(Weapons[weapon].ReloadTime, function()
        if self.Current == weapon then
            self.Ammo = Weapons[weapon].MagSize
        end
        self.Reloading = false
    end)
end

function WeaponController:Equip(name)
    if not Weapons[name] then
        return
    end
    self.Current = name
    self.Ammo = Weapons[name].MagSize
    self.Reloading = false
end

function WeaponController:KnitStart()
    local holding = false
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = true
        end
        if input.KeyCode == Enum.KeyCode.R then
            self:Reload()
        end
        if input.KeyCode == Enum.KeyCode.One then
            self:Equip("AssaultRifle")
        end
        if input.KeyCode == Enum.KeyCode.Two then
            self:Equip("Shotgun")
        end
        if input.KeyCode == Enum.KeyCode.Three then
            self:Equip("Sniper")
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if holding then
            self:Fire()
        end
    end)
end

return WeaponController
