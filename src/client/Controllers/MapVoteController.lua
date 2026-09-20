-- Lobby map vote card. Shown only to the players who filled a pad, for MapVoteSeconds, between
-- the queue filling and the match starting. Tap a map or press its number key; the tally updates
-- live for everyone voting.
--
-- Layout: one centred card. The lobby has no crosshair to avoid, but the card still goes through
-- Screen so it scales on a phone, stays inside the safe area, and keeps 44pt tap targets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Screen = require(script.Parent.Parent.UI.Screen)

local MapVoteController = Knit.CreateController({ Name = "MapVoteController" })

-- A card is a surface sitting on the vote panel, and a picked card is a toggled-on control, so
-- both come from the shared surface ramp rather than adding two more near-duplicate greys.
local PANEL = Theme.Color.Panel
local CARD = Theme.Color.PanelRaised
local CARD_PICKED = Theme.Color.PanelSelected
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local ACCENT = Theme.Color.Accent

-- One per card the ballot can show. MapVoteOptions is capped at the rotation size, so this has
-- to keep up with the longest rotation (Convergence, five maps) or a card shows a key hint for a
-- key nothing listens to. keyHint() below refuses to promise a binding that is not here.
local NUMBER_KEYS = {
    Enum.KeyCode.One,
    Enum.KeyCode.Two,
    Enum.KeyCode.Three,
    Enum.KeyCode.Four,
    Enum.KeyCode.Five,
    Enum.KeyCode.Six,
}

local function keyHint(index)
    if Screen.isTouch() then
        return "TAP"
    end
    return NUMBER_KEYS[index] and ("PRESS " .. index) or "CLICK"
end

function MapVoteController:BuildGui()
    local gui = Screen.newScreenGui("MapVoteGui", Screen.Layers.MapVote)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.45)
    panel.Size = UDim2.fromOffset(880, 260)
    panel.BackgroundColor3 = PANEL
    panel.BackgroundTransparency = Theme.Transparency.Panel
    panel.Parent = gui
    -- 880x260 is the desktop size, sized for the widest ballot: five 150 px cards plus four
    -- 12 px gaps is 798, inside the 844 px of panel left after padding. autoScale and fitWithin
    -- shrink it from there, and the cards ride the same UIScale, so a phone in landscape gets a
    -- smaller version of the same layout rather than a row that overflows the panel.
    Screen.autoScale(panel)
    Screen.fitWithin(panel, 0.94, 0.8)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 18)
    pad.PaddingRight = UDim.new(0, 18)
    pad.Parent = panel

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundTransparency = 1
    title.Text = "VOTE FOR THE NEXT MAP"
    title.TextSize = Theme.textSize(Theme.Type.Title)
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = TEXT
    title.Parent = panel

    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.Position = UDim2.fromOffset(0, 30)
    timer.Size = UDim2.new(1, 0, 0, 18)
    timer.BackgroundTransparency = 1
    timer.TextSize = Theme.textSize(Theme.Type.Label)
    timer.Font = Enum.Font.GothamMedium
    timer.TextColor3 = ACCENT
    timer.Parent = panel
    self.Timer = timer

    local row = Instance.new("Frame")
    row.Name = "Choices"
    row.Position = UDim2.fromOffset(0, 58)
    row.Size = UDim2.new(1, 0, 1, -58)
    row.BackgroundTransparency = 1
    row.Parent = panel
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 12)
    layout.Parent = row
    self.Row = row

    self.Panel = panel
end

-- One card per candidate. `Screen.tapSize` keeps it tappable on a phone; the design size is what
-- it wants on a desktop.
function MapVoteController:BuildChoice(index, mapName)
    local button = Instance.new("TextButton")
    button.Name = "Choice" .. index
    button.LayoutOrder = index
    button.Size = UDim2.fromOffset(Screen.tapSize(150), Screen.tapSize(120))
    button.BackgroundColor3 = CARD
    button.AutoButtonColor = true
    button.Text = ""
    button.Parent = self.Row
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button
    -- Outline for the picked state, invisible until this card is the one voted for.
    local outline = Instance.new("UIStroke")
    outline.Thickness = 3
    outline.Color = CARD
    outline.Transparency = 1
    outline.Parent = button

    local name = Instance.new("TextLabel")
    name.Position = UDim2.fromScale(0, 0.16)
    name.Size = UDim2.new(1, 0, 0, 24)
    name.BackgroundTransparency = 1
    name.Text = mapName:upper()
    name.TextSize = Theme.textSize(Theme.Type.Body)
    name.TextScaled = false
    name.Font = Enum.Font.GothamBold
    name.TextColor3 = TEXT
    name.Parent = button

    local key = Instance.new("TextLabel")
    key.Name = "Hint"
    key.Position = UDim2.fromScale(0, 0.45)
    key.Size = UDim2.new(1, 0, 0, 16)
    key.BackgroundTransparency = 1
    key.Text = keyHint(index)
    key.TextSize = Theme.textSize(Theme.Type.Label)
    key.Font = Enum.Font.GothamMedium
    key.TextColor3 = MUTED
    key.Parent = button

    local votes = Instance.new("TextLabel")
    votes.Name = "Votes"
    votes.Position = UDim2.fromScale(0, 0.66)
    votes.Size = UDim2.new(1, 0, 0, 22)
    votes.BackgroundTransparency = 1
    votes.Text = "0"
    votes.TextSize = Theme.textSize(Theme.Type.Title)
    votes.Font = Enum.Font.GothamBlack
    votes.TextColor3 = ACCENT
    votes.Parent = button

    button.Activated:Connect(function()
        self:Vote(index)
    end)
    return button
end

function MapVoteController:Vote(index)
    if not self.Open or not self.Choices[index] then
        return
    end
    self.Picked = index
    for i, button in self.Choices do
        local picked = i == index
        button.BackgroundColor3 = picked and CARD_PICKED or CARD
        -- Colour is never the only signal: the picked card also takes an accent outline, so it
        -- still reads for a colour-blind player and at a glance.
        local outline = button:FindFirstChildOfClass("UIStroke")
        if outline then
            outline.Color = picked and ACCENT or CARD
            outline.Transparency = picked and 0 or 1
        end
    end
    Knit.GetService("MapVoteService"):Vote(index)
end

function MapVoteController:Show(maps, seconds)
    for _, button in self.Choices or {} do
        button:Destroy()
    end
    self.Choices = {}
    for i, mapName in maps do
        self.Choices[i] = self:BuildChoice(i, mapName)
    end
    self.Open = true
    self.Picked = nil
    self.Deadline = os.clock() + seconds
    self.Gui.Enabled = true
end

function MapVoteController:Hide(winnerName)
    self.Open = false
    if winnerName then
        self.Timer.Text = "NEXT MAP: " .. winnerName:upper()
        task.delay(2, function()
            if not self.Open then
                self.Gui.Enabled = false
            end
        end)
    else
        self.Gui.Enabled = false
    end
end

function MapVoteController:KnitStart()
    self:BuildGui()
    self.Choices = {}

    -- Card size and the tap/press hint follow the device, so a rotation or a controller being
    -- picked up mid-vote re-lays the cards out instead of leaving desktop sizes on a phone.
    Screen.onChange(function()
        for i, button in self.Choices or {} do
            button.Size = UDim2.fromOffset(Screen.tapSize(150), Screen.tapSize(120))
            local hint = button:FindFirstChild("Hint")
            if hint then
                hint.Text = keyHint(i)
            end
        end
    end)

    local MapVoteService = Knit.GetService("MapVoteService")
    MapVoteService.Opened:Connect(function(maps, seconds)
        self:Show(maps, seconds)
    end)
    MapVoteService.Tally:Connect(function(counts)
        for i, button in self.Choices do
            local votes = button:FindFirstChild("Votes")
            if votes then
                votes.Text = tostring(counts[i] or 0)
            end
        end
    end)
    MapVoteService.Closed:Connect(function(winnerName)
        self:Hide(winnerName)
    end)

    -- Number keys are a convenience; the cards are the real control and work everywhere.
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not self.Open then
            return
        end
        for i, code in NUMBER_KEYS do
            if input.KeyCode == code then
                self:Vote(i)
                return
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not self.Open then
            return
        end
        local left = math.max(0, self.Deadline - os.clock())
        self.Timer.Text = ("%ds left"):format(math.ceil(left))
    end)
end

return MapVoteController
