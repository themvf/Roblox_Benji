-- Persistent lobby navigation: efficient actions live in the HUD while the physical
-- Armory, Kits/Shop bays, and team pads remain discovery and practice spaces.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Lore = require(ReplicatedStorage.Shared.Lore)
local LobbyCatalog = require(script.Parent.Parent.UI.LobbyCatalog)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local LobbyNavigationController = Knit.CreateController({ Name = "LobbyNavigationController" })

local PANEL = Theme.Color.PanelRaised
local PANEL_LIGHT = Theme.Color.PanelHigh
local PANEL_SELECTED = Theme.Color.PanelSelected
local ACCENT = Theme.Color.Accent
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local RED = Theme.team("Red")
local BLUE = Theme.team("Blue")

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

local function textSize(size)
    local step
    if size >= 26 then
        step = Theme.Type.Display
    elseif size >= 20 then
        step = Theme.Type.Title
    elseif size >= 15 then
        step = Theme.Type.Body
    else
        step = Theme.Type.Label
    end
    -- The drawer uses proportional sizing rather than UIScale, so convert the
    -- theme's design size to the same physical size as a scaled panel.
    return math.max(Theme.Type.Label, math.floor(Theme.textSize(step) * Screen.get().Scale + 0.5))
end

local function corner(instance, radius)
    local ui = Instance.new("UICorner")
    ui.CornerRadius = UDim.new(0, radius or 10)
    ui.Parent = instance
    return ui
end

local function outline(instance, color, thickness)
    local ui = Instance.new("UIStroke")
    ui.Color = color
    ui.Thickness = thickness or 2
    ui.Parent = instance
    return ui
end

local function label(parent, text, size, color, font)
    local ui = Instance.new("TextLabel")
    ui.BackgroundTransparency = 1
    ui.Text = text
    ui.TextSize = textSize(size)
    ui:SetAttribute("DesignTextSize", size)
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
    ui.TextSize = textSize(16)
    ui:SetAttribute("DesignTextSize", 16)
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
    local gui = Screen.newScreenGui("LobbyNavigationGui", Screen.Layers.Lobby)
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    local nav = Instance.new("Frame")
    nav.AnchorPoint = Vector2.new(0.5, 1)
    nav.Position = UDim2.new(0.5, 0, 1, -18)
    nav.Size = UDim2.fromOffset(716, 64)
    nav.BackgroundColor3 = PANEL
    nav.BackgroundTransparency = Theme.Transparency.Panel
    nav.Parent = gui
    corner(nav, 14)
    outline(nav, PANEL_SELECTED, 1)
    Screen.autoScale(nav)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = nav

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = nav
    self.Nav = nav

    -- Centered hero PLAY CTA flanked cleanly by preparation, storefront, and profile actions.
    -- On compact phones, CUSTOMIZE and PROFILE fold into MORE to preserve safe touch margins.
    local actions = {
        {
            Id = "LOADOUT",
            Order = 1,
            OnClick = function()
                self:OpenEditor("Loadout")
            end,
        },
        {
            Id = "SHOP",
            Order = 2,
            OnClick = function()
                self:OpenDrawer("Shop")
            end,
        },
        {
            Id = "PLAY",
            Order = 3,
            Primary = true,
            OnClick = function()
                self:OpenDrawer("Play")
            end,
        },
        {
            Id = "CUSTOMIZE",
            Order = 4,
            OnClick = function()
                self:OpenEditor("Customize")
            end,
        },
        {
            Id = "PROFILE",
            Order = 5,
            OnClick = function()
                self:OpenDrawer("Profile")
            end,
        },
        {
            Id = "MORE",
            Order = 6,
            OnClick = function()
                self:OpenDrawer("More")
            end,
        },
    }

    self.NavButtons = {}
    for _, action in actions do
        local navButton = button(nav, action.Id, action.Primary and ACCENT or PANEL_LIGHT)
        navButton.Size = UDim2.fromOffset(action.Primary and 156 or 124, 48)
        navButton.TextColor3 = action.Primary and Theme.Color.Panel or TEXT
        navButton.LayoutOrder = action.Order
        if action.Primary then
            navButton.Font = Enum.Font.GothamBlack
            outline(navButton, TEXT, 1)
        end
        navButton.Activated:Connect(action.OnClick)
        self.NavButtons[action.Id] = navButton
    end

    local queueBadge = label(gui, "", 14, ACCENT, Enum.Font.GothamBold)
    queueBadge.AnchorPoint = Vector2.new(0.5, 1)
    queueBadge.Position = UDim2.new(0.5, 0, 1, -86)
    queueBadge.Size = UDim2.fromOffset(560, 28)
    queueBadge.BackgroundTransparency = Theme.Transparency.Panel
    queueBadge.BackgroundColor3 = PANEL
    queueBadge.TextXAlignment = Enum.TextXAlignment.Center
    queueBadge.TextSize = Theme.textSize(Theme.Type.Label)
    queueBadge.Visible = false
    corner(queueBadge, 8)
    outline(queueBadge, ACCENT, 1)
    Screen.autoScale(queueBadge)
    self.QueueBadge = queueBadge

    local drawer = Instance.new("Frame")
    drawer.AnchorPoint = Vector2.new(0.5, 0.5)
    drawer.Position = UDim2.fromScale(0.5, 0.46)
    drawer.Size = UDim2.fromScale(0.76, 0.7)
    drawer.BackgroundColor3 = PANEL
    drawer.BackgroundTransparency = Theme.Transparency.Panel
    drawer.Visible = false
    drawer.Parent = gui
    corner(drawer, 16)
    outline(drawer, PANEL_SELECTED, 2)
    self.DrawerConstraint = Screen.fitWithin(drawer, 0.92, 0.88)
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

    Screen.onChange(function(state)
        self:ApplyResponsiveLayout(state)
    end)
end

function LobbyNavigationController:ApplyResponsiveLayout(state)
    for _, descendant in self.Gui:GetDescendants() do
        local designSize = descendant:GetAttribute("DesignTextSize")
        if designSize then
            descendant.TextSize = textSize(designSize)
        end
    end

    local compactPhone = state.Class == "Phone"
    local buttonHeight = state.Touch and math.ceil(Screen.tapSize(48) / state.Scale) or 48
    local gap = 8

    self.NavButtons.CUSTOMIZE.Visible = not compactPhone
    self.NavButtons.PROFILE.Visible = not compactPhone
    self.NavButtons.MORE.Visible = compactPhone

    local totalWidth = 16 -- left + right padding
    local visibleCount = 0
    for name, navButton in self.NavButtons do
        if navButton.Visible then
            visibleCount += 1
            local width
            if compactPhone then
                width = name == "PLAY" and 126 or 106
            else
                width = name == "PLAY" and 156 or 124
            end
            navButton.Size = UDim2.fromOffset(width, buttonHeight)
            navButton.TextSize = Theme.textSize(state.Touch and Theme.Type.Label or Theme.Type.Body)
            totalWidth += width
        end
    end
    totalWidth += math.max(0, visibleCount - 1) * gap

    self.Nav.Size = UDim2.fromOffset(totalWidth, buttonHeight + 16)
    self.QueueBadge.TextSize = Theme.textSize(Theme.Type.Label)
    self.DrawerConstraint.MaxSize =
        Vector2.new(math.min(840, state.Viewport.X * 0.92), math.min(660, state.Viewport.Y * 0.88))

    if state.Touch then
        -- The touch hotbar and movement controls own the bottom edge in the lobby too.
        self.Nav.AnchorPoint = Vector2.new(1, 0)
        self.Nav.Position = UDim2.new(1, -state.Insets.Right, 0, state.Insets.Top + 4)
        self.QueueBadge.AnchorPoint = Vector2.new(1, 0)
        self.QueueBadge.Position =
            UDim2.new(1, -state.Insets.Right, 0, state.Insets.Top + (buttonHeight + 16) * state.Scale + 12)
        self.Drawer.Size = UDim2.fromScale(0.94, 0.82)
    else
        self.Nav.AnchorPoint = Vector2.new(0.5, 1)
        -- Reserve the bottom centre for Roblox's backpack hotbar.
        self.Nav.Position = UDim2.new(0.5, 0, 1, -state.Insets.Bottom - 110)
        self.QueueBadge.AnchorPoint = Vector2.new(0.5, 1)
        self.QueueBadge.Position = UDim2.new(0.5, 0, 1, -state.Insets.Bottom - 178)
        self.Drawer.Size = UDim2.fromScale(0.76, 0.7)
    end
    self:RefreshQueueBadge()
end

function LobbyNavigationController:OpenEditor(section)
    self:CloseDrawer()
    Knit.GetController("LoadoutController"):Open(section)
end

function LobbyNavigationController:OpenDrawer(kind, initialTab)
    Knit.GetController("LoadoutController"):Close()
    self.ActiveDrawer = kind
    if kind == "Shop" and initialTab then
        self.ActiveShopTab = initialTab
    end
    self.Drawer.Visible = true
    if kind == "Play" then
        self:RenderPlay()
    elseif kind == "Shop" then
        self:RenderShop()
    elseif kind == "More" then
        self:RenderMore()
    else
        self:RenderProfile()
    end
    GuiService.SelectedObject = self.DrawerClose
end

function LobbyNavigationController:CloseDrawer()
    self.Drawer.Visible = false
    self.ActiveDrawer = nil
    GuiService.SelectedObject = Screen.get().Class == "Console" and self.Nav.Visible and self.NavButtons.PLAY or nil
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

    local queuedMode = Players.LocalPlayer:GetAttribute("QueuedMode")
    local queuedTeam = Players.LocalPlayer:GetAttribute("QueuedTeam")
    local queueState = Players.LocalPlayer:GetAttribute("QueueState")
    local y = 0
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
        outline(banner, ACCENT, 1)

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
        if queuedMode == status.Mode then
            outline(card, ACCENT, 2)
        end

        local mode = label(card, status.Mode, 20, TEXT, Enum.Font.GothamBlack)
        mode.Position = UDim2.fromOffset(14, 10)
        mode.Size = UDim2.new(1, -260, 0, 28)
        local info = label(card, status.Status, 13, MUTED, Enum.Font.GothamMedium)
        info.Position = UDim2.fromOffset(14, 42)
        info.Size = UDim2.new(1, -260, 0, 44)
        info.TextWrapped = true

        local redName = Lore.teamName("Red"):upper()
        local isRed = queuedMode == status.Mode and queuedTeam == "Red"
        local redText = isRed and ("QUEUED\n" .. redName) or ("%s\n%d/%d"):format(redName, status.Red, status.TeamSize)
        local red = button(card, redText, RED)
        red.TextWrapped = true
        red.AnchorPoint = Vector2.new(1, 0)
        red.Position = UDim2.new(1, -128, 0, 18)
        red.Size = UDim2.fromOffset(112, 64)
        if isRed then
            outline(red, ACCENT, 2)
        end
        red.Activated:Connect(function()
            self:QueueAction(status.Mode, "Red")
        end)

        local blueName = Lore.teamName("Blue"):upper()
        local isBlue = queuedMode == status.Mode and queuedTeam == "Blue"
        local blueText = isBlue and ("QUEUED\n" .. blueName)
            or ("%s\n%d/%d"):format(blueName, status.Blue, status.TeamSize)
        local blue = button(card, blueText, BLUE)
        blue.TextWrapped = true
        blue.AnchorPoint = Vector2.new(1, 0)
        blue.Position = UDim2.new(1, -10, 0, 18)
        blue.Size = UDim2.fromOffset(112, 64)
        if isBlue then
            outline(blue, ACCENT, 2)
        end
        blue.Activated:Connect(function()
            self:QueueAction(status.Mode, "Blue")
        end)
    end

    if #self.Statuses == 0 then
        local loading = label(self.Content, "Loading available modes...", 16, MUTED, Enum.Font.GothamMedium)
        loading.Position = UDim2.fromOffset(0, y)
        loading.Size = UDim2.new(1, 0, 0, 40)
    end

    local setupY = y + math.max(#self.Statuses * 112, 52) + 18
    self:AddLoadoutStrip(self.Content, setupY)
    local edit = button(self.Content, "EDIT LOADOUT", PANEL_LIGHT)
    edit.Position = UDim2.fromOffset(0, setupY + 100)
    edit.Size = UDim2.fromOffset(170, 44)
    edit.Activated:Connect(function()
        self:OpenEditor("Loadout")
    end)
end

function LobbyNavigationController:RenderCatalogCard(entry, index, topY)
    local accentColor = Theme.Color[entry.Accent] or ACCENT
    local card = Instance.new("Frame")
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    card.Position = UDim2.new(column * 0.5, column * 6, 0, topY + row * 150)
    card.Size = UDim2.new(0.5, -6, 0, 138)
    card.BackgroundColor3 = PANEL_LIGHT
    card.Parent = self.Content
    corner(card, 12)
    outline(card, entry.Live and accentColor or PANEL_SELECTED, entry.Live and 2 or 1)

    local badge = label(card, entry.Badge, 11, entry.Live and Theme.Color.Panel or accentColor, Enum.Font.GothamBlack)
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Position = UDim2.new(1, -12, 0, 12)
    badge.Size = UDim2.fromOffset(108, 22)
    badge.BackgroundTransparency = 0
    badge.BackgroundColor3 = entry.Live and accentColor or PANEL
    badge.TextXAlignment = Enum.TextXAlignment.Center
    badge.TextYAlignment = Enum.TextYAlignment.Center
    corner(badge, 6)

    local title = label(card, entry.Title, 16, accentColor, Enum.Font.GothamBlack)
    title.Position = UDim2.fromOffset(14, 10)
    title.Size = UDim2.new(1, -134, 0, 24)
    title.TextTruncate = Enum.TextTruncate.AtEnd

    local subtitle = label(card, entry.Subtitle, 12, MUTED, Enum.Font.GothamMedium)
    subtitle.Position = UDim2.fromOffset(14, 34)
    subtitle.Size = UDim2.new(1, -28, 0, 18)
    subtitle.TextTruncate = Enum.TextTruncate.AtEnd

    local summary = label(card, entry.Summary, 13, TEXT, Enum.Font.GothamMedium)
    summary.Position = UDim2.fromOffset(14, 56)
    summary.Size = UDim2.new(1, -28, 0, 42)
    summary.TextWrapped = true
    summary.TextYAlignment = Enum.TextYAlignment.Top

    local detail = label(card, entry.Detail, 11, MUTED, Enum.Font.GothamBold)
    detail.Position = UDim2.fromOffset(14, 104)
    detail.Size = UDim2.new(1, -28, 0, 22)
    detail.TextTruncate = Enum.TextTruncate.AtEnd
end

function LobbyNavigationController:RenderShop()
    if self.ActiveDrawer ~= "Shop" then
        return
    end
    clearContent(self.Content)
    self.ActiveShopTab = self.ActiveShopTab or "Kits"
    self.DrawerTitle.Text = self.ActiveShopTab:upper()

    local tabRow = Instance.new("Frame")
    tabRow.Position = UDim2.fromOffset(0, 0)
    tabRow.Size = UDim2.new(1, -8, 0, 46)
    tabRow.BackgroundTransparency = 1
    tabRow.Parent = self.Content

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabRow

    for order, tabInfo in LobbyCatalog.Tabs do
        local selected = self.ActiveShopTab == tabInfo.Id
        local tabBtn = button(tabRow, tabInfo.Label, selected and ACCENT or PANEL_LIGHT)
        tabBtn.Size = UDim2.fromOffset(124, 42)
        tabBtn.TextColor3 = selected and Theme.Color.Panel or TEXT
        tabBtn.LayoutOrder = order
        tabBtn.Activated:Connect(function()
            self.ActiveShopTab = tabInfo.Id
            self:RenderShop()
        end)
    end

    local noticeText = self.ActiveShopTab == "Kits"
            and "PREVIEW  •  Titan is live under Loadout → Alter Ego. Additional Kits unlock once KitService ships."
        or "PREVIEW  •  Store bundles and passes are scaffolded here; purchases unlock once StoreService ships."
    local notice = label(self.Content, noticeText, 13, ACCENT, Enum.Font.GothamBold)
    notice.Position = UDim2.fromOffset(0, 56)
    notice.Size = UDim2.new(1, -8, 0, 44)
    notice.BackgroundTransparency = 0
    notice.BackgroundColor3 = PANEL_LIGHT
    notice.TextXAlignment = Enum.TextXAlignment.Center
    notice.TextYAlignment = Enum.TextYAlignment.Center
    notice.TextWrapped = true
    corner(notice, 10)

    local items = LobbyCatalog[self.ActiveShopTab] or {}
    for index, entry in items do
        self:RenderCatalogCard(entry, index, 114)
    end
end

function LobbyNavigationController:RenderMore()
    if self.ActiveDrawer ~= "More" then
        return
    end
    clearContent(self.Content)
    self.DrawerTitle.Text = "MORE"

    local customize = button(self.Content, "CUSTOMIZE  ·  SKINS, CHARACTER & CELEBRATIONS", PANEL_LIGHT)
    customize.Position = UDim2.fromOffset(0, 4)
    customize.Size = UDim2.new(1, -8, 0, 56)
    customize.Activated:Connect(function()
        self:OpenEditor("Customize")
    end)

    local profile = button(self.Content, "PROFILE  ·  CAREER STATS & LEVEL", PANEL_LIGHT)
    profile.Position = UDim2.fromOffset(0, 72)
    profile.Size = UDim2.new(1, -8, 0, 56)
    profile.Activated:Connect(function()
        self:OpenDrawer("Profile")
    end)

    local kits = button(self.Content, "KITS, PACKS & PASSES  ·  PREVIEW", PANEL_LIGHT)
    kits.Position = UDim2.fromOffset(0, 140)
    kits.Size = UDim2.new(1, -8, 0, 56)
    kits.Activated:Connect(function()
        self:OpenDrawer("Shop", "Kits")
    end)
end

function LobbyNavigationController:RenderProfile()
    clearContent(self.Content)
    self.DrawerTitle.Text = "PROFILE"
    local player = Players.LocalPlayer
    local name = label(self.Content, player.DisplayName, 26, TEXT, Enum.Font.GothamBlack)
    name.Size = UDim2.new(1, 0, 0, 38)
    local alterEgo = pretty(player:GetAttribute("AlterEgo") or "Titan")
    local handle = label(
        self.Content,
        ("@%s  ·  Active Alter Ego: %s"):format(player.Name, alterEgo),
        14,
        MUTED,
        Enum.Font.GothamMedium
    )
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
        if Screen.get().Touch then
            self.QueueBadge.Text = ("SEARCHING: %s • %s"):format(mode, team or "")
        else
            self.QueueBadge.Text = ("SEARCHING: %s • %s TEAM • LOADOUT EDITING AVAILABLE"):format(mode, team or "")
        end
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
    Screen.start()
    self.Statuses = {}
    self.ActiveDrawer = nil
    self.ActiveShopTab = "Kits"
    self.QueueError = nil
    self:BuildGui()
    self:RefreshVisibility()
    if Screen.get().Class == "Console" and self.Nav.Visible then
        GuiService.SelectedObject = self.NavButtons.PLAY
    end

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
