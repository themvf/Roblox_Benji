-- Hold Tab for the match scoreboard: score, K/D/A, captures, stops, bounty, streak per player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ScoreboardController = Knit.CreateController({ Name = "ScoreboardController" })

local PANEL = Color3.fromRGB(20, 22, 28)
local MUTED = Color3.fromRGB(160, 165, 180)
local RED = Color3.fromRGB(255, 90, 90)
local BLUE = Color3.fromRGB(90, 150, 255)
local ACCENT = Color3.fromRGB(255, 200, 70)

local COLS = {
    { "Player", 0.28 },
    { "Score", 0.12 },
    { "K", 0.07 },
    { "D", 0.07 },
    { "A", 0.07 },
    { "Cap", 0.08 },
    { "Stop", 0.08 },
    { "Bounty", 0.15 },
    { "Streak", 0.08 },
}

function ScoreboardController:BuildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Scoreboard"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.DisplayOrder = 15
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui
    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0.7, 0, 0, 60)
    panel.BackgroundColor3 = PANEL
    panel.BackgroundTransparency = 0.15
    panel.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = panel
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 2)
    list.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = panel
    self.Panel = panel
    self:Row(0, { "Player", "Score", "K", "D", "A", "Cap", "Stop", "Bounty", "Streak" }, MUTED, true)
end

function ScoreboardController:Row(order, values, color, header)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, header and 22 or 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = self.Panel
    local x = 0
    for i, col in COLS do
        local l = Instance.new("TextLabel")
        l.Position = UDim2.fromScale(x, 0)
        l.Size = UDim2.fromScale(col[2], 1)
        l.BackgroundTransparency = 1
        l.Text = tostring(values[i] or "")
        l.TextSize = header and 13 or 16
        l.Font = header and Enum.Font.GothamBold or Enum.Font.GothamMedium
        l.TextColor3 = color
        l.TextXAlignment = i == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Parent = row
        x += col[2]
    end
    return row
end

function ScoreboardController:Apply(rows)
    for _, c in self.Panel:GetChildren() do
        if c:IsA("Frame") and c.LayoutOrder > 0 then
            c:Destroy()
        end
    end
    for i, r in rows do
        local color = r.Team == "Red" and RED or BLUE
        local name = r.Name
        if r.Bounty then
            name = "★ " .. name
        end
        self:Row(i, {
            name,
            r.Score,
            r.Kills,
            r.Deaths,
            r.Assists,
            r.Captures,
            r.Stops,
            r.Bounty or "",
            r.Streak > 0 and ("🔥" .. r.Streak) or "",
        }, r.Bounty and ACCENT or color)
    end
    self.Panel.Size = UDim2.new(0.7, 0, 0, 16 + 24 + #rows * 28)
end

-- Touch: tap to open, tap again to close (no key to hold)
function ScoreboardController:Toggle()
    if self.Gui.Enabled then
        self.Gui.Enabled = false
    elseif self.Rows then
        self:Apply(self.Rows)
        self.Gui.Enabled = true
    end
end

function ScoreboardController:KnitStart()
    self:BuildGui()
    Knit.GetService("StatsService").Scoreboard:Connect(function(rows)
        self.Rows = rows
        if self.Gui.Enabled then
            self:Apply(rows)
        end
    end)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end
        if input.KeyCode == Enum.KeyCode.Tab and self.Rows then
            self:Apply(self.Rows)
            self.Gui.Enabled = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Tab then
            self.Gui.Enabled = false
        end
    end)
    Knit.GetService("RoundService").StateChanged:Connect(function(state)
        if state == "Lobby" then
            self.Rows = nil
            self.Gui.Enabled = false
        end
    end)
end

return ScoreboardController
