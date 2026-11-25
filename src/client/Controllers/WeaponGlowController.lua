-- Flares a gun's glowing part on every shot (the Plasma Blaster's Neon core, 2026-11-23).
--
-- tools/build_weapons.luau tags such a tool with the attribute GlowPart = "<part name>" and puts a
-- PointLight named GlowLight in that part. The Weapons Kit clones the gun's "Fired" sound into the
-- gun for every shot, on every client (BaseWeapon:tryPlaySound), so a new "Fired" sound under a
-- tagged tool is the shot. The light jumps to the flare brightness and settles back; the Neon part
-- whitens a little with it. Numbers are Tuning attributes WeaponGlow_<Key> (Config.WeaponGlow).
-- Client only: nothing here touches gameplay.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local WeaponGlowController = Knit.CreateController({ Name = "WeaponGlowController" })

local WHITEN = 0.35 -- how far the Neon colour moves toward white at the peak of a flare

local function setting(key: string): number
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    local value = tuning and tuning:GetAttribute("WeaponGlow_" .. key)
    return if type(value) == "number" then value else Config.WeaponGlow[key]
end

local resting: { [BasePart]: Color3 } = {}

local function flare(tool: Tool)
    local name = tool:GetAttribute("GlowPart")
    local part = type(name) == "string" and tool:FindFirstChild(name, true)
    if not (part and part:IsA("BasePart")) then
        return
    end
    local base = resting[part] or part.Color
    resting[part] = base
    local seconds = setting("FlareSeconds")
    local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    part.Color = base:Lerp(Color3.new(1, 1, 1), WHITEN)
    TweenService:Create(part, info, { Color = base }):Play()
    local light = part:FindFirstChild("GlowLight")
    if light and light:IsA("PointLight") then
        light.Range = setting("LightRange")
        light.Brightness = setting("FlareBrightness")
        TweenService:Create(light, info, { Brightness = setting("LightBrightness") }):Play()
    end
end

function WeaponGlowController:KnitStart()
    workspace.DescendantAdded:Connect(function(inst)
        if inst.Name ~= "Fired" or not inst:IsA("Sound") then
            return
        end
        local tool = inst:FindFirstAncestorWhichIsA("Tool")
        if tool and tool:GetAttribute("GlowPart") then
            flare(tool)
        end
    end)
end

return WeaponGlowController
