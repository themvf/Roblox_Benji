-- Visual feedback: bullet tracers, hit markers, damage numbers, team name colors.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local EffectsController = Knit.CreateController({ Name = "EffectsController" })

local TEAM_COLORS = {
    Red = Color3.fromRGB(255, 70, 70),
    Blue = Color3.fromRGB(70, 140, 255),
}

function EffectsController:DrawTracer(origin, endPoint)
    local dist = (endPoint - origin).Magnitude
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(255, 230, 120)
    part.Size = Vector3.new(0.08, 0.08, dist)
    part.CFrame = CFrame.lookAt(origin, endPoint) * CFrame.new(0, 0, -dist / 2)
    part.Parent = workspace
    TweenService:Create(part, TweenInfo.new(0.12), { Transparency = 1 }):Play()
    Debris:AddItem(part, 0.15)
end

function EffectsController:DrawTracers(origin, endPoints)
    for _, p in endPoints do
        self:DrawTracer(origin, p)
    end
end

function EffectsController:ShowHit(damage, headshot)
    local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("Hud")
    if not gui then
        return
    end
    -- Hit marker: brief X at screen center
    local marker = Instance.new("TextLabel")
    marker.AnchorPoint = Vector2.new(0.5, 0.5)
    marker.Position = UDim2.fromScale(0.5, 0.5)
    marker.Size = UDim2.fromOffset(40, 40)
    marker.BackgroundTransparency = 1
    marker.Text = "X"
    marker.TextScaled = true
    marker.Font = Enum.Font.GothamBold
    marker.TextColor3 = headshot and Color3.fromRGB(255, 60, 60) or Color3.new(1, 1, 1)
    marker.Parent = gui
    Debris:AddItem(marker, 0.15)

    -- Floating damage number
    local num = Instance.new("TextLabel")
    num.AnchorPoint = Vector2.new(0.5, 0.5)
    num.Position = UDim2.new(0.5, math.random(-60, 60), 0.45, 0)
    num.Size = UDim2.fromOffset(60, 30)
    num.BackgroundTransparency = 1
    num.Text = tostring(damage)
    num.TextScaled = true
    num.Font = Enum.Font.GothamBold
    num.TextColor3 = headshot and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 220, 80)
    num.Parent = gui
    TweenService:Create(num, TweenInfo.new(0.6), {
        Position = num.Position - UDim2.fromScale(0, 0.08),
        TextTransparency = 1,
    }):Play()
    Debris:AddItem(num, 0.6)
end

local function colorName(character, team)
    local head = character:WaitForChild("Head", 5)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not head or not hum then
        return
    end
    hum.DisplayName = (team or "?") .. " | " .. hum.DisplayName
    local color = TEAM_COLORS[team]
    if color then
        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 1
        highlight.OutlineColor = color
        highlight.OutlineTransparency = 0.2
        highlight.Parent = character
    end
end

function EffectsController:KnitStart()
    local WeaponService = Knit.GetService("WeaponService")
    WeaponService.Tracer:Connect(function(_shooter, origin, endPoints)
        self:DrawTracers(origin, endPoints)
    end)
    WeaponService.Hit:Connect(function(damage, headshot)
        self:ShowHit(damage, headshot)
    end)

    local function watch(player)
        player.CharacterAdded:Connect(function(character)
            colorName(character, player:GetAttribute("Team"))
        end)
        if player.Character then
            colorName(player.Character, player:GetAttribute("Team"))
        end
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return EffectsController
