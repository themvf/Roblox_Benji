-- Health and ammo, Rivals-style: one slim strip centred just above the weapon slots, where
-- the eye already goes to see what is in hand. Health is a bar with the number on it; ammo is
-- "12 / 30" beside it for the held gun. Holding the jetpack swaps ammo for a fuel bar.
--
-- Replaces Roblox's CoreGui health bar, which sat in the top-right corner away from
-- everything else the player reads mid-fight. The Weapons Kit draws no ammo counter, so
-- without this there was none at all.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Icons = require(script.Parent.Parent.UI.Icons)

local VitalsController = Knit.CreateController({ Name = "VitalsController" })

local WIDTH = 300
local HEIGHT = 26
local GAP = 8 -- above the weapon slots

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = inst
end

-- icon + bar + number, the shape both health and fuel take
local function meter(parent, iconName, color, x, width)
    local holder = Instance.new("Frame")
    holder.Position = UDim2.fromOffset(x, 0)
    holder.Size = UDim2.fromOffset(width, HEIGHT)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local iconBox = Instance.new("Frame")
    iconBox.Size = UDim2.fromOffset(HEIGHT - 4, HEIGHT - 4)
    iconBox.Position = UDim2.fromOffset(0, 2)
    iconBox.BackgroundTransparency = 1
    iconBox.Parent = holder
    local icon = Icons.make(iconBox, iconName)
    Icons.tint(icon, color)

    local track = Instance.new("Frame")
    track.Position = UDim2.fromOffset(HEIGHT + 2, 4)
    track.Size = UDim2.new(1, -(HEIGHT + 2), 1, -8)
    track.BackgroundColor3 = Theme.Color.Track
    track.BorderSizePixel = 0
    track.Parent = holder
    corner(track, 4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, 4)
    local number = Instance.new("TextLabel")
    number.Size = UDim2.fromScale(1, 1)
    number.BackgroundTransparency = 1
    number.Text = ""
    number.TextSize = Theme.textSize(Theme.Type.Label)
    number.Font = Enum.Font.GothamBlack
    number.TextColor3 = Theme.Color.Text
    number.ZIndex = 2
    number.Parent = track
    Theme.overWorld(number, 1.5) -- sits on the coloured fill, which has no fixed contrast
    return { Holder = holder, Fill = fill, Number = number, Icon = icon }
end

function VitalsController:BuildGui()
    local gui = Screen.newScreenGui("Vitals", Screen.Layers.Hotbar)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    local strip = Instance.new("Frame")
    strip.Name = "Strip"
    strip.AnchorPoint = Vector2.new(0.5, 1)
    strip.Size = UDim2.fromOffset(WIDTH, HEIGHT)
    strip.BackgroundTransparency = 1
    strip.Parent = gui
    Screen.autoScale(strip)
    self.Strip = strip

    self.Health = meter(strip, "Health", Theme.Color.Good, 0, 190)
    self.Fuel = meter(strip, "Fuel", Theme.Color.Fly, 200, 100)

    -- ammo: icon + "12 / 30", no bar -- a count is read, not estimated
    local ammo = Instance.new("Frame")
    ammo.Position = UDim2.fromOffset(200, 0)
    ammo.Size = UDim2.fromOffset(100, HEIGHT)
    ammo.BackgroundColor3 = Theme.Color.Panel
    ammo.BackgroundTransparency = Theme.Transparency.Panel
    ammo.Parent = strip
    corner(ammo, 6)
    local iconBox = Instance.new("Frame")
    iconBox.Size = UDim2.fromOffset(HEIGHT - 6, HEIGHT - 6)
    iconBox.Position = UDim2.fromOffset(4, 3)
    iconBox.BackgroundTransparency = 1
    iconBox.Parent = ammo
    local icon = Icons.make(iconBox, "Ammo")
    Icons.tint(icon, Theme.Color.Accent)
    local count = Instance.new("TextLabel")
    count.Position = UDim2.fromOffset(HEIGHT, 0)
    count.Size = UDim2.new(1, -HEIGHT - 4, 1, 0)
    count.BackgroundTransparency = 1
    count.Text = ""
    count.TextSize = Theme.textSize(Theme.Type.Body)
    count.Font = Enum.Font.GothamBlack
    count.TextColor3 = Theme.Color.Text
    count.TextXAlignment = Enum.TextXAlignment.Right
    count.Parent = ammo
    self.Ammo, self.AmmoCount = ammo, count

    Screen.onChange(function(state)
        local bar = Knit.GetController("WeaponBarController")
        local above = bar.SLOT_HEIGHT + bar.BOTTOM_GAP + GAP
        strip.Position = UDim2.new(0.5, 0, 1, -state.Insets.Bottom - above)
    end)
end

function VitalsController:Update()
    local me = Players.LocalPlayer
    local character = me.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    self.Gui.Enabled = me:GetAttribute("InMatch") == true and hum ~= nil
    if not self.Gui.Enabled then
        return
    end

    local hp = math.max(0, hum.Health)
    local frac = hum.MaxHealth > 0 and hp / hum.MaxHealth or 0
    self.Health.Fill.Size = UDim2.fromScale(frac, 1)
    self.Health.Fill.BackgroundColor3 = frac > 0.5 and Theme.Color.Good
        or (frac > 0.25 and Theme.Color.Warn or Theme.Color.Danger)
    self.Health.Number.Text = tostring(math.ceil(hp))

    local tool = character:FindFirstChildOfClass("Tool")
    local jet = Knit.GetController("JetpackController")
    local current = tool and tool:FindFirstChild("CurrentAmmo")
    local config = tool and tool:FindFirstChild("Configuration")
    local capacity = config and config:FindFirstChild("AmmoCapacity")

    self.Fuel.Holder.Visible = jet.Active
    if jet.Active and jet.MaxFuel > 0 then
        self.Fuel.Fill.Size = UDim2.fromScale(math.clamp(jet.Fuel / jet.MaxFuel, 0, 1), 1)
        self.Fuel.Number.Text = ("%d%%"):format(100 * jet.Fuel / jet.MaxFuel)
    end

    local showAmmo = not jet.Active and current ~= nil and current:IsA("IntValue")
    self.Ammo.Visible = showAmmo
    -- nothing beside it (melee, empty hands): centre the health bar on the slots
    local besides = showAmmo or jet.Active
    self.Health.Holder.Position = UDim2.fromOffset(besides and 0 or (WIDTH - 190) / 2, 0)
    if showAmmo then
        local cap = capacity and capacity.Value or 0
        -- the kit stores 999 for a weapon with no magazine (melee-like), which is not a count
        self.AmmoCount.Text = cap > 0 and cap < 999 and ("%d / %d"):format(current.Value, cap)
            or tostring(current.Value)
        self.AmmoCount.TextColor3 = current.Value == 0 and Theme.Color.Danger or Theme.Color.Text
    end
end

function VitalsController:KnitStart()
    -- this strip is the health readout now; two health bars would disagree about where to look
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
    end)
    self:BuildGui()
    RunService.RenderStepped:Connect(function()
        self:Update()
    end)
end

return VitalsController
