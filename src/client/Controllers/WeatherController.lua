-- Client-local weather FX driven by workspace attributes set by MapService.
-- Keeps rain around the active camera only while on a Hurricane map (never inside Lobby).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local WeatherController = Knit.CreateController({ Name = "WeatherController" })

local MIST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local RAIN_OFFSET_UP = 34
local RAIN_OFFSET_FWD = 18

local function createStormRig()
    local volume = Instance.new("Part")
    volume.Name = "HurricaneRainVolume"
    volume.Size = Vector3.new(60, 2, 60)
    volume.Anchored = true
    volume.CanCollide = false
    volume.CanTouch = false
    volume.CanQuery = false
    volume.CastShadow = false
    volume.Transparency = 1
    volume.Parent = workspace

    local rain = Instance.new("ParticleEmitter")
    rain.Name = "Rain"
    rain.Enabled = false
    rain.Orientation = Enum.ParticleOrientation.VelocityParallel
    rain.EmissionDirection = Enum.NormalId.Bottom
    rain.Color = ColorSequence.new(Color3.fromRGB(215, 230, 250))
    rain.LightEmission = 0.35
    rain.LightInfluence = 0.5
    rain.Size = NumberSequence.new(0.42)
    rain.Squash = NumberSequence.new(2.6)
    rain.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.75),
        NumberSequenceKeypoint.new(0.15, 0.25),
        NumberSequenceKeypoint.new(0.85, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    rain.Lifetime = NumberRange.new(0.7, 0.95)
    rain.Speed = NumberRange.new(68, 86)
    rain.Acceleration = Vector3.new(24, -95, 10)
    rain.SpreadAngle = Vector2.new(8, 8)
    rain.Rate = 500
    rain.Parent = volume

    local mist = Instance.new("ParticleEmitter")
    mist.Name = "WindMist"
    mist.Enabled = false
    mist.Texture = MIST_TEXTURE
    mist.EmissionDirection = Enum.NormalId.Bottom
    mist.Color = ColorSequence.new(Color3.fromRGB(130, 150, 175))
    mist.LightInfluence = 0.7
    mist.Size = NumberSequence.new(6, 13)
    mist.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.45, 0.88),
        NumberSequenceKeypoint.new(1, 1),
    })
    mist.Lifetime = NumberRange.new(1.4, 2.2)
    mist.Speed = NumberRange.new(24, 38)
    mist.Acceleration = Vector3.new(30, -6, 12)
    mist.SpreadAngle = Vector2.new(22, 22)
    mist.Rate = 18
    mist.Parent = volume

    return volume, rain, mist
end

function WeatherController:IsStormActive()
    if workspace:GetAttribute("MapWeather") ~= "Hurricane" then
        return false
    end
    local player = Players.LocalPlayer
    if not player then
        return true
    end
    return player:GetAttribute("Team") ~= "Lobby" or player:GetAttribute("Exploring") == true
end

function WeatherController:ApplyState()
    local active = self:IsStormActive()
    self.Active = active
    if not self.Rain or not self.Mist then
        return
    end
    self.Rain.Enabled = active
    self.Mist.Enabled = active
    if not active then
        self.Rain:Clear()
        self.Mist:Clear()
        self.NextLightningAt = nil
        if self.RainAudio and self.RainAudio.IsPlaying then
            self.RainAudio:Stop()
        end
        local base = workspace:GetAttribute("MapBaseBrightness")
        if type(base) == "number" then
            Lighting.Brightness = base
        end
    else
        if not self.NextLightningAt then
            self.NextLightningAt = os.clock() + math.random(6, 12)
        end
        local rainId = Uploads.resolve("upload:HurricaneRain")
        if rainId then
            if not self.RainAudio then
                local s = Instance.new("Sound")
                s.Name = "HurricaneRainLoop"
                s.Looped = true
                s.Volume = 0.45
                s.Parent = self.Volume
                self.RainAudio = s
            end
            if self.RainAudio.SoundId ~= rainId then
                self.RainAudio.SoundId = rainId
            end
            if not self.RainAudio.IsPlaying then
                self.RainAudio:Play()
            end
        end
    end
end

function WeatherController:PulseLightning()
    if self.Flashing or not self.Active then
        return
    end
    self.Flashing = true
    local thunderId = Uploads.resolve("upload:Thunder")
    if thunderId then
        local t = Instance.new("Sound")
        t.SoundId = thunderId
        t.Volume = 0.65
        t.Parent = self.Volume
        t:Play()
        Debris:AddItem(t, 8)
    end
    task.spawn(function()
        local base = tonumber(workspace:GetAttribute("MapBaseBrightness")) or Lighting.Brightness
        local steps = {
            { mult = 2.0, waitSec = 0.07 },
            { mult = 1.0, waitSec = 0.08 },
            { mult = 1.65, waitSec = 0.06 },
        }
        for _, step in steps do
            if not self.Active then
                break
            end
            Lighting.Brightness = base * step.mult
            task.wait(step.waitSec)
        end
        local restore = tonumber(workspace:GetAttribute("MapBaseBrightness")) or base
        Lighting.Brightness = restore
        self.Flashing = false
    end)
end

function WeatherController:KnitStart()
    local volume, rain, mist = createStormRig()
    self.Volume = volume
    self.Rain = rain
    self.Mist = mist
    self.Active = false
    self.Flashing = false

    workspace:GetAttributeChangedSignal("MapWeather"):Connect(function()
        self:ApplyState()
    end)
    local player = Players.LocalPlayer
    if player then
        player:GetAttributeChangedSignal("Team"):Connect(function()
            self:ApplyState()
        end)
        player:GetAttributeChangedSignal("Exploring"):Connect(function()
            self:ApplyState()
        end)
    end
    self:ApplyState()

    RunService.RenderStepped:Connect(function()
        if not self.Active then
            return
        end
        local cam = workspace.CurrentCamera
        if cam then
            local pos = cam.CFrame.Position
                + cam.CFrame.LookVector * RAIN_OFFSET_FWD
                + Vector3.new(0, RAIN_OFFSET_UP, 0)
            self.Volume.CFrame = CFrame.new(pos)
        end
        if self.NextLightningAt and os.clock() >= self.NextLightningAt then
            self.NextLightningAt = os.clock() + math.random(8, 16)
            self:PulseLightning()
        end
    end)
end

return WeatherController
