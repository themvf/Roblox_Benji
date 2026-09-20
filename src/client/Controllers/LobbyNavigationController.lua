-- Persistent lobby navigation: efficient actions live in the HUD while the physical
-- Armory and team pads remain discovery and practice spaces.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local LobbyNavigationController = Knit.CreateController({ Name = "LobbyNavigationController" })

local PANEL = Color3.fromRGB(28, 30, 38)
local PANEL_LIGHT = Color3.fromRGB(44, 47, 58)
local ACCENT = Color3.fromRGB(255, 200, 70)
local TEXT = Color3.fromRGB(245, 245, 250)
local MUTED = Color3.fromRGB(160, 165, 180)
local RED = Color3.fromRGB(230, 85, 85)
local BLUE = Color3.fromRGB(75, 140, 255)

local LOADOUT_SLOTS = { "Primary", "Secondary", "Melee", "Utility", "AlterEgo" }
local PROFILE_STATS = {
    "Level",
    "XP",
    "Wins",
    "Losses",
    "Matches",
    "Kills",
    "Deaths",
    "Assists",
    "Captures",
    "MVPs",
}

local function corner(instance, radius)
    local ui = Instance.new("UICorner")
    ui.CornerRadius = UDim.new(0, radius or 10)
    ui.Parent = instance
end

local function outline(instance, color, thickness)
    local ui = Instance.new("UIStroke")
    ui.Color = color
    ui.Thickness = thickness or 2
    ui.Parent = instance
end

local function label(parent, text, size, color, font)
    local ui = Instance.new("TextLabel")
    ui.BackgroundTransparency = 1
    ui.Text = text
    ui.TextSize = size
    ui.TextColor3 = color or TEXT
    ui.Font = font or Enum.Font.GothamBold
    ui.TextXAlignment = Enum.TextXAlignment.Left
    ui.Parent = parent
    return ui
end

local function button(parent, text, color)
    local ui = Instance.new("TextButton")
    ui.AutoButtonColor = false
    ui.BackgroundColor3 = color or PANEL_LIGHT
    ui.Text = text
    ui.TextColor3 = TEXT
    ui.TextSize = 16
    ui.Font = Enum.Font.GothamBold
    ui.Selectable = true
    ui.Parent = parent
    corner(ui, 10)
    return ui
end

local function pretty(value)
    if not value or value == "" or value == "__NONE__" then
        return "NONE"
    end
    return value:gsub("(%l)(%u)", "%1 %2"):upper()
end

local function clearContent(parent)
    for _, child in parent:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

function LobbyNavigationController:BuildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "LobbyNavigationGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 30
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    local nav = Instance.new("Frame")
    nav.AnchorPoint = Vector2.new(0.5, 1)
    nav.Position = UDim2.new(0.5, 0, 1, -18)
    nav.Size = UDim2.fromOffset(600, 64)
    nav.BackgroundColor3 = PANEL
    nav.BackgroundTransparency = 0.08
    nav.Parent = gui
    corner(nav, 14)
    outline(nav, Color3.fromRGB(70, 74, 88), 1)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = nav
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = nav
    self.Nav = nav

    local actions = {
        {
            "PLAY",
            function()
                self:OpenDrawer("Play")
            end,
        },
        {
            "LOADOUT",
            function()
                self:OpenEditor("Loadout")
            end,
        },
        {
            "CUSTOMIZE",
            function()
                self:OpenEditor("Customize")
            end,
        },
        {
            "PROFILE",
            function()
                self:OpenDrawer("Profile")
            end,
        },
    }
    self.NavButtons = {}
    for index, action in actions do
        local navButton = button(nav, action[1], index == 1 and ACCENT or PANEL_LIGHT)
        navButton.Size = UDim2.fromOffset(138, 48)
        navButton.TextColor3 = index == 1 and PANEL or TEXT
        navButton.LayoutOrder = index
        navButton.Activated:Connect(action[2])
        self.NavButtons[action[1]] = navButton
    end

    local queueBadge = label(gui, "", 14, ACCENT, Enum.Font.GothamBold)
    queueBadge.AnchorPoint = Vector2.new(0.5, 1)
    queueBadge.Position = UDim2.new(0.5, 0, 1, -86)
    queueBadge.Size = UDim2.fromOffset(560, 28)
    queueBadge.BackgroundTransparency = 0.12
    queueBadge.BackgroundColor3 = PANEL
    queueBadge.TextXAlignment = Enum.TextXAlignment.Center
    queueBadge.Visible = false
    corner(queueBadge, 8)
    self.QueueBadge = queueBadge

    local drawer = Instance.new("Frame")
    drawer.AnchorPoint = Vector2.new(0.5, 0.5)
    drawer.Position = UDim2.fromScale(0.5, 0.46)
    drawer.Size = UDim2.fromScale(0.76, 0.7)
    drawer.BackgroundColor3 = PANEL
    drawer.Visible = false
    drawer.Parent = gui
    corner(drawer, 16)
    outline(drawer, Color3.fromRGB(75, 79, 94), 2)
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(820, 650)
    constraint.Parent = drawer
    self.Drawer = drawer

    local drawerTitle = label(drawer, "PLAY", 30, ACCENT, Enum.Font.GothamBlack)
    drawerTitle.Position = UDim2.fromOffset(22, 14)
    drawerTitle.Size = UDim2.new(1, -90, 0, 40)
    self.DrawerTitle = drawerTitle

    local close = button(drawer, "X", PANEL_LIGHT)
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -16, 0, 12)
    close.Size = UDim2.fromOffset(44, 44)
    close.Activated:Connect(function()
        self:CloseDrawer()
    end)
    self.DrawerClose = close

    local content = Instance.new("ScrollingFrame")
    content.Position = UDim2.new(0, 22, 0, 66)
    content.Size = UDim2.new(1, -44, 1, -86)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 5
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.CanvasSize = UDim2.new()
    content.Parent = drawer
    self.Content = content

    self:ApplyResponsiveLayout()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        self:ApplyResponsiveLayout()
    end)
end

function LobbyNavigationController:ApplyResponsiveLayout()
    local width = workspace.CurrentCamera.ViewportSize.X
    if width < 680 then
        self.Nav.Size = UDim2.new(1, -16, 0, 58)
        for _, navButton in self.NavButtons do
            navButton.Size = UDim2.new(0.25, -10, 0, 42)
            navButton.TextSize = 12
        end
        self.Drawer.Size = UDim2.fromScale(0.94, 0.74)
    else
        self.Nav.Size = UDim2.fromOffset(600, 64)
        for _, navButton in self.NavButtons do
            navButton.Size = UDim2.fromOffset(138, 48)
            navButton.TextSize = 16
        end
        self.Drawer.Size = UDim2.fromScale(0.76, 0.7)
    end
end

function LobbyNavigationController:OpenEditor(section)
    self:CloseDrawer()
    Knit.GetController("LoadoutController"):Open(section)
end

function LobbyNavigationController:OpenDrawer(kind)
    Knit.GetController("LoadoutController"):Close()
    self.ActiveDrawer = kind
    self.Drawer.Visible = true
    if kind == "Play" then
        self:RenderPlay()
    else
        self:RenderProfile()
    end
    GuiService.SelectedObject = self.DrawerClose
end

function LobbyNavigationController:CloseDrawer()
    self.Drawer.Visible = false
    self.ActiveDrawer = nil
    GuiService.SelectedObject = nil
end

function LobbyNavigationController:AddLoadoutStrip(parent, y)
    local heading = label(parent, "CURRENT LOADOUT", 14, MUTED, Enum.Font.GothamBold)
    heading.Position = UDim2.fromOffset(0, y)
    heading.Size = UDim2.new(1, 0, 0, 22)

    local row = Instance.new("Frame")
    row.Position = UDim2.fromOffset(0, y + 26)
    row.Size = UDim2.new(1, 0, 0, 64)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.Parent = row
    for index, slot in LOADOUT_SLOTS do
        local attribute = slot == "AlterEgo" and "AlterEgo" or ("Loadout" .. slot)
        local value = Players.LocalPlayer:GetAttribute(attribute)
        local chip = label(row, slot:upper() .. "\n" .. pretty(value), 11, TEXT, Enum.Font.GothamBold)
        chip.Size = UDim2.new(0.2, -5, 1, 0)
        chip.BackgroundTransparency = 0
        chip.BackgroundColor3 = PANEL_LIGHT
        chip.TextXAlignment = Enum.TextXAlignment.Center
        chip.TextYAlignment = Enum.TextYAlignment.Center
        chip.TextWrapped = true
        chip.LayoutOrder = index
        corner(chip, 8)
    end
end

function LobbyNavigationController:QueueAction(mode, team)
    Knit.GetService("QueueService"):Join(mode, team):andThen(function(ok, reason)
        if not ok then
            self.QueueError = reason == "match_locked" and "Your match is starting." or "That queue is unavailable."
        else
            self.QueueError = nil
        end
        self:RenderPlay()
        self:RefreshQueueBadge()
    end)
end

function LobbyNavigationController:RenderPlay()
    if self.ActiveDrawer ~= "Play" then
        return
    end
    clearContent(self.Content)
    self.DrawerTitle.Text = "PLAY"
    self:AddLoadoutStrip(self.Content, 0)

    local edit = button(self.Content, "EDIT LOADOUT", PANEL_LIGHT)
    edit.Position = UDim2.fromOffset(0, 100)
    edit.Size = UDim2.fromOffset(170, 42)
    edit.Activated:Connect(function()
        self:OpenEditor("Loadout")
    end)

    local queuedMode = Players.LocalPlayer:GetAttribute("QueuedMode")
    local queuedTeam = Players.LocalPlayer:GetAttribute("QueuedTeam")
    local queueState = Players.LocalPlayer:GetAttribute("QueueState")
    local y = 154
    if queueState == "Queued" and queuedMode then
        local banner = label(
            self.Content,
            ("SEARCHING  •  %s  •  %s TEAM\nKeep editing—your setup locks only when the match starts."):format(
                queuedMode,
                queuedTeam or ""
            ),
            15,
            ACCENT,
            Enum.Font.GothamBold
        )
        banner.Position = UDim2.fromOffset(0, y)
        banner.Size = UDim2.new(1, -130, 0, 58)
        banner.BackgroundTransparency = 0
        banner.BackgroundColor3 = PANEL_LIGHT
        banner.TextXAlignment = Enum.TextXAlignment.Center
        banner.TextYAlignment = Enum.TextYAlignment.Center
        banner.TextWrapped = true
        corner(banner, 10)
        local leave = button(self.Content, "LEAVE", PANEL_LIGHT)
        leave.AnchorPoint = Vector2.new(1, 0)
        leave.Position = UDim2.new(1, 0, 0, y)
        leave.Size = UDim2.fromOffset(118, 58)
        leave.Activated:Connect(function()
            Knit.GetService("QueueService"):Leave():andThen(function()
                self:RenderPlay()
                self:RefreshQueueBadge()
            end)
        end)
        y += 72
    elseif self.QueueError then
        local errorLabel = label(self.Content, self.QueueError, 14, RED, Enum.Font.GothamBold)
        errorLabel.Position = UDim2.fromOffset(0, y)
        errorLabel.Size = UDim2.new(1, 0, 0, 28)
        y += 38
    end

    for index, status in self.Statuses do
        local card = Instance.new("Frame")
        card.Position = UDim2.new(0, 0, 0, y + (index - 1) * 112)
        card.Size = UDim2.new(1, -8, 0, 102)
        card.BackgroundColor3 = PANEL_LIGHT
        card.Parent = self.Content
        corner(card, 12)

        local mode = label(card, status.Mode, 20, TEXT, Enum.Font.GothamBlack)
        mode.Position = UDim2.fromOffset(14, 10)
        mode.Size = UDim2.new(1, -260, 0, 28)
        local info = label(card, status.Status, 13, MUTED, Enum.Font.GothamMedium)
        info.Position = UDim2.fromOffset(14, 42)
        info.Size = UDim2.new(1, -260, 0, 44)
        info.TextWrapped = true

        local redText = queuedMode == status.Mode and queuedTeam == "Red" and "QUEUED RED"
            or ("RED %d/%d"):format(status.Red, status.TeamSize)
        local red = button(card, redText, RED)
        red.AnchorPoint = Vector2.new(1, 0)
        red.Position = UDim2.new(1, -128, 0, 18)
        red.Size = UDim2.fromOffset(112, 64)
        red.Activated:Connect(function()
            self:QueueAction(status.Mode, "Red")
        end)

        local blueText = queuedMode == status.Mode and queuedTeam == "Blue" and "QUEUED BLUE"
            or ("BLUE %d/%d"):format(status.Blue, status.TeamSize)
        local blue = button(card, blueText, BLUE)
        blue.AnchorPoint = Vector2.new(1, 0)
        blue.Position = UDim2.new(1, -10, 0, 18)
        blue.Size = UDim2.fromOffset(112, 64)
        blue.Activated:Connect(function()
            self:QueueAction(status.Mode, "Blue")
        end)
    end

    if #self.Statuses == 0 then
        local loading = label(self.Content, "Loading available modes...", 16, MUTED, Enum.Font.GothamMedium)
        loading.Position = UDim2.fromOffset(0, y)
        loading.Size = UDim2.new(1, 0, 0, 40)
    end
end

function LobbyNavigationController:RenderProfile()
    clearContent(self.Content)
    self.DrawerTitle.Text = "PROFILE"
    local player = Players.LocalPlayer
    local name = label(self.Content, player.DisplayName, 26, TEXT, Enum.Font.GothamBlack)
    name.Size = UDim2.new(1, 0, 0, 38)
    local handle = label(self.Content, "@" .. player.Name, 14, MUTED, Enum.Font.GothamMedium)
    handle.Position = UDim2.fromOffset(0, 38)
    handle.Size = UDim2.new(1, 0, 0, 24)

    for index, stat in PROFILE_STATS do
        local card = Instance.new("Frame")
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        card.Position = UDim2.new(column * 0.5, column * 5, 0, 80 + row * 66)
        card.Size = UDim2.new(0.5, -5, 0, 56)
        card.BackgroundColor3 = PANEL_LIGHT
        card.Parent = self.Content
        corner(card, 10)
        local statName = label(card, stat:upper(), 12, MUTED, Enum.Font.GothamBold)
        statName.Position = UDim2.fromOffset(12, 7)
        statName.Size = UDim2.new(0.6, 0, 0, 18)
        local value = label(card, tostring(player:GetAttribute(stat) or 0), 20, TEXT, Enum.Font.GothamBlack)
        value.Position = UDim2.fromOffset(12, 25)
        value.Size = UDim2.new(1, -24, 0, 24)
    end
end

function LobbyNavigationController:RefreshQueueBadge()
    local state = Players.LocalPlayer:GetAttribute("QueueState")
    local mode = Players.LocalPlayer:GetAttribute("QueuedMode")
    local team = Players.LocalPlayer:GetAttribute("QueuedTeam")
    self.QueueBadge.Visible = state == "Queued" and mode ~= nil
    if self.QueueBadge.Visible then
        self.QueueBadge.Text = ("SEARCHING: %s • %s TEAM • LOADOUT EDITING AVAILABLE"):format(mode, team or "")
    end
end

function LobbyNavigationController:RefreshVisibility()
    local player = Players.LocalPlayer
    local committed = player:GetAttribute("QueueState") == "Committed"
    local visible = not player:GetAttribute("InMatch") and not committed
    self.Nav.Visible = visible
    self.QueueBadge.Visible = visible and self.QueueBadge.Visible
    if not visible then
        self:CloseDrawer()
    else
        self:RefreshQueueBadge()
    end
end

function LobbyNavigationController:KnitStart()
    self.Statuses = {}
    self.ActiveDrawer = nil
    self.QueueError = nil
    self:BuildGui()
    self:RefreshVisibility()

    local queueService = Knit.GetService("QueueService")
    queueService:GetStatus():andThen(function(statuses)
        self.Statuses = statuses
        if self.ActiveDrawer == "Play" then
            self:RenderPlay()
        end
    end)
    queueService.Changed:Connect(function(statuses)
        self.Statuses = statuses
        if self.ActiveDrawer == "Play" then
            self:RenderPlay()
        end
        self:RefreshQueueBadge()
    end)

    local player = Players.LocalPlayer
    for _, attribute in { "InMatch", "QueueState", "QueuedMode", "QueuedTeam" } do
        player:GetAttributeChangedSignal(attribute):Connect(function()
            self:RefreshVisibility()
            if self.ActiveDrawer == "Play" then
                self:RenderPlay()
            end
        end)
    end
    for _, slot in LOADOUT_SLOTS do
        local attribute = slot == "AlterEgo" and "AlterEgo" or ("Loadout" .. slot)
        player:GetAttributeChangedSignal(attribute):Connect(function()
            if self.ActiveDrawer == "Play" then
                self:RenderPlay()
            end
        end)
    end
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not self.Drawer.Visible then
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
            self:CloseDrawer()
        end
    end)
end

return LobbyNavigationController
