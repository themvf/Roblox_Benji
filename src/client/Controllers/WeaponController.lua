-- Handles input, ammo, bursts, and reload timing, then asks the server to validate each shot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local WeaponController = Knit.CreateController({ Name = "WeaponController" })

-- Rivals default loadout: Assault Rifle + Handgun
WeaponController.Loadout = { Primary = "AssaultRifle", Secondary = "Handgun" }
WeaponController.Current = "AssaultRifle"
WeaponController.Reloading = false
WeaponController.Equipping = false
WeaponController.AmmoState = {} -- [weaponName] = { Mag = n, Reserve = n }

local lastShot = 0
local firing = false -- true while a burst is in progress

local function ammoFor(self, name)
    local state = self.AmmoState[name]
    if not state then
        local stats = Weapons[name]
        state = { Mag = stats.Ammo[1], Reserve = stats.Ammo[2] }
        self.AmmoState[name] = state
    end
    return state
end

function WeaponController:GetAmmo()
    return ammoFor(self, self.Current)
end

function WeaponController:Stats()
    return Weapons[self.Current]
end

function WeaponController:FireOne(name, ammo)
    ammo.Mag -= 1
    local cam = workspace.CurrentCamera
    local origin = cam.CFrame.Position
    local look = cam.CFrame.LookVector
    Knit.GetService("WeaponService"):Fire(name, origin, look)

    -- Local tracer so your own shots feel instant; others see the server's version.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Players.LocalPlayer.Character }
    local hit = workspace:Raycast(origin, look * 1000, params)
    Knit.GetController("EffectsController"):DrawTracer(origin, hit and hit.Position or origin + look * 1000)
end

function WeaponController:Fire()
    local name = self.Current
    local stats = self:Stats()
    local ammo = self:GetAmmo()
    if self.Reloading or self.Equipping or firing then
        return
    end
    if ammo.Mag <= 0 then
        self:Reload()
        return
    end
    if os.clock() - lastShot < stats.Cooldown then
        return
    end
    lastShot = os.clock()

    if stats.Burst then
        firing = true
        task.spawn(function()
            for i = 1, stats.Burst do
                if ammo.Mag <= 0 or self.Current ~= name then
                    break
                end
                self:FireOne(name, ammo)
                if i < stats.Burst then
                    task.wait(stats.BurstDelay)
                end
            end
            firing = false
            if ammo.Mag == 0 then
                self:Reload()
            end
        end)
    else
        self:FireOne(name, ammo)
        if ammo.Mag == 0 then
            self:Reload()
        end
    end
end

function WeaponController:Reload()
    local stats = self:Stats()
    local ammo = self:GetAmmo()
    if self.Reloading or ammo.Mag >= stats.Ammo[1] or ammo.Reserve <= 0 then
        return
    end
    self.Reloading = true
    local weapon = self.Current
    local duration = stats.Reload
    if ammo.Mag == 0 and stats.EmptyReload then
        duration = stats.EmptyReload
    end

    task.spawn(function()
        if stats.SegmentedReload then
            -- Shotgun style: one shell at a time, interrupted by switching weapons.
            while self.Current == weapon and ammo.Mag < stats.Ammo[1] and ammo.Reserve > 0 do
                task.wait(duration)
                if self.Current ~= weapon then
                    break
                end
                ammo.Mag += 1
                ammo.Reserve -= 1
            end
        else
            task.wait(duration)
            if self.Current == weapon then
                local need = stats.Ammo[1] - ammo.Mag
                local take = math.min(need, ammo.Reserve)
                ammo.Mag += take
                ammo.Reserve -= take
            end
        end
        self.Reloading = false
    end)
end

function WeaponController:Equip(name)
    if not Weapons[name] or name == self.Current then
        return
    end
    self.Current = name
    self.Reloading = false
    self.Equipping = true
    Knit.GetService("WeaponService"):Equip(name)
    task.delay(Weapons[name].EquipTime, function()
        if self.Current == name then
            self.Equipping = false
        end
    end)
end

function WeaponController:KnitStart()
    local holding = false
    -- Hand the model over whenever a character spawns
    local player = Players.LocalPlayer
    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid")
        task.wait(0.2)
        Knit.GetService("WeaponService"):Equip(self.Current)
    end)
    if player.Character then
        Knit.GetService("WeaponService"):Equip(self.Current)
    end
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = true
            self:Fire() -- semi-auto weapons fire once per click
        end
        if input.KeyCode == Enum.KeyCode.R then
            self:Reload()
        end
        if input.KeyCode == Enum.KeyCode.One then
            self:Equip(self.Loadout.Primary)
        end
        if input.KeyCode == Enum.KeyCode.Two then
            self:Equip(self.Loadout.Secondary)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if holding and self:Stats().Auto then
            self:Fire()
        end
    end)
end

return WeaponController
