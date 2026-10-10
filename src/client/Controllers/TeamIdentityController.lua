local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Controller = Knit.CreateController({ Name = "TeamIdentityController" })

function Controller:KnitStart()
    local me = Players.LocalPlayer
    local gui = Screen.newScreenGui("TeamIdentity", Screen.Layers.Meter)
    gui.Parent = me:WaitForChild("PlayerGui")
    local badge = Instance.new("TextLabel")
    badge.Name = "YourTeam"
    badge.Size = UDim2.fromOffset(126, 28)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 14
    badge.TextColor3 = Color3.new(1, 1, 1)
    badge.BackgroundTransparency = 0.1
    badge.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = badge
    Screen.onChange(function(s)
        badge.Position = UDim2.fromOffset(s.Insets.Left, s.Insets.Top + (s.Viewport.X < 600 and 104 or 6))
    end)
    local function refresh()
        local team = me:GetAttribute("Team")
        gui.Enabled = me:GetAttribute("InMatch") == true and (team == "Red" or team == "Blue")
        badge.Text = team == "Red" and "RED TEAM" or "BLUE TEAM"
        badge.BackgroundColor3 = team == "Red" and Theme.Team.Red or Theme.Team.Blue
    end
    me:GetAttributeChangedSignal("Team"):Connect(refresh)
    me:GetAttributeChangedSignal("InMatch"):Connect(refresh)
    refresh()
end

return Controller
