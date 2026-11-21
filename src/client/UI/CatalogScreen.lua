-- CatalogScreen: three ready-made screens that draw CatalogItem records.
--
--   Browser  tabs, a filter, cards, an optional 3D preview, detail and one primary action.
--            Kits, packs, the pass list, skins: anything browsed without a clock running.
--   LockIn   one row of usable items, a short summary and a server countdown. No purchases.
--   Track    a season track: tiers with a free and a premium row.
--
-- A new screen is a controller of about thirty lines: make one of these, hand it records from
-- the server with :SetItems, and answer OnAction by asking the server. The screen never changes
-- a record itself, so a rejected request cannot leave a false "equipped" or "owned" on screen.
--
--   local screen = CatalogScreen.new({
--       Name = "KitBrowser", Template = "Browser", Title = "KITS",
--       Tabs = { { Id = "Kit", Label = "KITS" } },      -- a tab shows the items of that Kind
--       OnAction = function(item, action) ... end,      -- "Equip", "Select", "Buy", "Claim"
--       Preview = function(frame, item) ... end,        -- optional: fill the preview area
--       ConfirmNote = "Kits are sidegrades, not upgrades.",
--   })
--   screen:SetItems(items)   screen:SetStatus("Saved.", "Good")   screen:Open()   screen:Close()
--
-- Everything is rebuilt from state on every change and on every Screen.onChange, so a rotation,
-- a Split View resize or a catalog refresh cannot leave a stale layout behind.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local CatalogItem = require(ReplicatedStorage.Shared.CatalogItem)
local Components = require(script.Parent.Components)
local Screen = require(script.Parent.Screen)
local Theme = require(script.Parent.Theme)

local CatalogScreen = {}
CatalogScreen.__index = CatalogScreen

CatalogScreen.Filters = {
    { Id = "Available", Label = "SHOW: AVAILABLE" },
    { Id = "Owned", Label = "SHOW: OWNED" },
    { Id = "All", Label = "SHOW: ALL" },
}

-- Design size of each template's panel; it shrinks to the viewport on small screens.
local DESIGN = {
    Browser = Vector2.new(1180, 660),
    LockIn = Vector2.new(980, 520),
    Track = Vector2.new(1180, 600),
}

local function place(instance, x, y, width, height)
    instance.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
    instance.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
    return instance
end

function CatalogScreen.new(config)
    assert(DESIGN[config.Template], "CatalogScreen: Template must be Browser, LockIn or Track")
    local self = setmetatable({}, CatalogScreen)
    self.Config = config
    self.Items = {}
    self.Tab = config.Tabs and config.Tabs[1] and config.Tabs[1].Id or nil
    self.Filter = config.Template == "LockIn" and "Available" or "All"
    self.Status = { Text = "", Tone = "TextMuted" }
    self.Focus = "close"

    local gui = Screen.newScreenGui(config.Name, config.Layer or Screen.Layers.Modal)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    local scrim = Instance.new("TextButton") -- a button, so presses do not reach the game behind
    scrim.Name = "Scrim"
    scrim.AutoButtonColor = false
    scrim.Selectable = false
    scrim.Text = ""
    scrim.BorderSizePixel = 0
    scrim.BackgroundColor3 = Theme.Color.Panel
    scrim.BackgroundTransparency = Theme.Transparency.Scrim
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.Parent = gui
    self.Scrim = scrim

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.BorderSizePixel = 0
    panel.BackgroundColor3 = Theme.Color.PanelRaised
    panel.BackgroundTransparency = Theme.Transparency.Panel
    panel.Parent = gui
    Components.corner(panel, 16)
    Components.stroke(panel, Theme.Color.PanelSelected, 2)
    Screen.autoScale(panel)
    self.Panel = panel

    local function redraw()
        if self.Gui.Enabled then
            self:Render()
        end
    end
    self._stopScreen = Screen.onChange(redraw)
    self._stopSettings = Components.onSettingsChanged(redraw)
    return self
end

-- ===== state =====

-- Records that fail CatalogItem.validate are left out and named in the output: a broken record
-- is never drawn as something the player can use.
function CatalogScreen:SetItems(items)
    local good = {}
    for _, item in items do
        local problems = CatalogItem.validate(item)
        if #problems == 0 then
            table.insert(good, item)
        else
            warn(("[CatalogScreen] %s left out: %s"):format(self.Config.Name, table.concat(problems, "; ")))
        end
    end
    self.Items = good
    self:Render()
end

function CatalogScreen:SetTrack(track)
    local problems = CatalogItem.validateTrack(track)
    if #problems > 0 then
        warn(("[CatalogScreen] %s track refused: %s"):format(self.Config.Name, table.concat(problems, "; ")))
        return
    end
    self.Track = track
    self:Render()
end

function CatalogScreen:SetStatus(text, tone)
    self.Status = { Text = text or "", Tone = tone or "TextMuted" }
    self:Render()
end

-- LockIn: the server's deadline and the map the match will be played on.
function CatalogScreen:SetDeadline(endsAt, mapName)
    self.EndsAt = endsAt
    self.MapName = mapName
    self:Render()
end

-- Show a shared state in place of the content while there is none to draw:
-- "Loading", "Empty", "Error" or "Offline" (Components.States). nil goes back to the content.
-- Error and Offline offer TRY AGAIN when the screen was given Config.OnRetry.
function CatalogScreen:SetLoad(kind, text)
    self.Load = kind and { Kind = kind, Text = text } or nil
    self:Render()
end

function CatalogScreen:IsOpen()
    return self.Gui.Enabled
end

function CatalogScreen:Visible()
    local shown = {}
    for _, item in self.Items do
        local access = CatalogItem.Access[item.Access]
        local inTab = self.Tab == nil or item.Kind == self.Tab
        local inFilter = self.Filter == "All"
            or (self.Filter == "Available" and access.Usable)
            or (self.Filter == "Owned" and (item.Access == "Owned" or item.Access == "Starter"))
        if inTab and inFilter then
            table.insert(shown, item)
        end
    end
    -- usable first, then as the server ordered them
    table.sort(shown, function(a, b)
        local ua, ub = CatalogItem.Access[a.Access].Usable, CatalogItem.Access[b.Access].Usable
        if ua ~= ub then
            return ua
        end
        return table.find(self.Items, a) < table.find(self.Items, b)
    end)
    return shown
end

function CatalogScreen:Viewed(shown)
    for _, item in shown do
        if item.Id == self.ViewingId then
            return item
        end
    end
    for _, item in shown do
        if item.Selected then
            return item
        end
    end
    return shown[1]
end

-- ===== lifecycle =====

function CatalogScreen:Open(tabId)
    if tabId then
        self.Tab = tabId
    end
    self.Focus = "viewing"
    self:Resume()
end

-- Show again without moving the focus: what UI/ScreenStack calls when the player comes back.
function CatalogScreen:Resume()
    self.Gui.Enabled = true
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:UnequipTools()
    end
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    end)
    -- The Weapons Kit locks the cursor every frame while a gun is held; free it last.
    RunService:BindToRenderStep(self.Config.Name .. "Mouse", Enum.RenderPriority.Last.Value, function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    if self.Config.Template ~= "LockIn" then
        ContextActionService:BindAction(self.Config.Name .. "Close", function(_, inputState)
            if inputState == Enum.UserInputState.Begin then
                self:Close()
            end
            return Enum.ContextActionResult.Sink
        end, false, Enum.KeyCode.ButtonB)
    end
    self:Render()
end

-- Hide without closing: another screen was opened on top. No OnClose, and the stack keeps it.
function CatalogScreen:Suspend()
    if not self.Gui.Enabled then
        return false
    end
    self.Gui.Enabled = false
    GuiService.SelectedObject = nil
    RunService:UnbindFromRenderStep(self.Config.Name .. "Mouse")
    ContextActionService:UnbindAction(self.Config.Name .. "Close")
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    end)
    return true
end

function CatalogScreen:Close()
    if not self:Suspend() then
        return
    end
    if self.Config.OnClose then
        self.Config.OnClose()
    end
    if self.Stack then
        self.Stack.closed(self)
    end
end

function CatalogScreen:Destroy()
    self:Close()
    self._stopScreen()
    self._stopSettings()
    self.Gui:Destroy()
end

-- ===== rendering =====

function CatalogScreen:Act(item, action)
    local spec = CatalogItem.Actions[action]
    if not spec or not spec.Enabled or not self.Config.OnAction then
        return
    end
    self.Focus = "action"
    if spec.Confirm then
        local note = self.Config.ConfirmNote and ("\n" .. self.Config.ConfirmNote) or ""
        local _, confirm = Components.confirm(self.Panel, {
            Title = "UNLOCK " .. item.Title,
            Body = ("%s for %s. This unlock is permanent.%s"):format(item.Title, Components.price(item.Price), note),
            ConfirmText = "BUY",
            OnConfirm = function()
                self.Config.OnAction(item, action)
            end,
            OnCancel = function()
                self:Render()
            end,
        })
        if GuiService.SelectedObject then
            GuiService.SelectedObject = confirm
        end
        return
    end
    self.Config.OnAction(item, action)
end

function CatalogScreen:Render()
    if not self.Gui.Enabled then
        return
    end
    local state = Screen.get()
    local design = DESIGN[self.Config.Template]
    -- a persistent strip (the queue status) may own the top of the screen; start below it
    local top, bottom = state.Insets.Top + Components.Reserve.Top, state.Insets.Bottom
    self.Panel.BackgroundTransparency = Components.surface(Theme.Transparency.Panel)
    self.Scrim.BackgroundTransparency = Components.surface(Theme.Transparency.Scrim)
    local width = math.min(design.X, (state.Viewport.X - state.Insets.Left - state.Insets.Right) * 0.96 / state.Scale)
    local height = (state.Viewport.Y - top - bottom) * 0.96 / state.Scale
    if width >= 900 then
        height = math.min(design.Y, height)
    else
        -- portrait and Split View: one column needs the height the wide layouts spend sideways
        height = math.min(design.Y * 1.7, height)
    end
    self.Panel.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
    self.Panel.Position = UDim2.new(0.5, 0, 0.5, (top - bottom) / 2)

    -- read before the rebuild: destroying the selected object clears the selection
    local gamepad = Components.usingGamepad()
    for _, child in self.Panel:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local body = Components.frame(self.Panel, "Body")
    body.Size = UDim2.fromScale(1, 1)
    self.Selectables = {}
    if self.Load then
        self:RenderLoad(body, width, height)
    else
        self["Render" .. self.Config.Template](self, body, width, height)
    end

    -- Controller and keyboard focus survives the rebuild.
    if gamepad then
        GuiService.SelectedObject = self.Selectables[self.Focus] or self.Selectables.viewing or self.Selectables.close
    end
end

-- Loading, empty, error or offline: the title, a way out, and one shared state block.
function CatalogScreen:RenderLoad(body, width, height)
    local pad, gap, tap = Components.PAD, Components.GAP, Components.tapHeight()
    local inner = width - pad * 2
    local y = pad
    if self.Config.Template == "LockIn" then
        -- no close button here: the match starts whether or not the kits arrived
        local title = Components.label(body, self.Config.Title or "LOCK-IN", "Title", {
            Name = "ScreenTitle",
            Color = Theme.Color.Accent,
            Font = Enum.Font.GothamBlack,
            Size = UDim2.fromOffset(0, 0),
        })
        place(title, pad, y, inner, tap)
    else
        self:Header(body, pad, y, inner, true)
    end
    y += tap + gap
    local retryable = self.Config.OnRetry ~= nil
    local block, retry = Components.state(body, self.Load.Kind, {
        Text = self.Load.Text,
        OnRetry = retryable and function()
            self.Focus = "viewing"
            self.Config.OnRetry()
        end or nil,
    })
    place(block, pad, y, inner, height - pad - y)
    self.Selectables.viewing = retry
end

function CatalogScreen:Header(body, x, y, width, showTitle)
    local tap = Components.tapHeight()
    if showTitle then
        local title = Components.label(body, self.Config.Title or "", "Display", {
            Name = "ScreenTitle",
            Color = Theme.Color.Accent,
            Font = Enum.Font.GothamBlack,
            Size = UDim2.fromOffset(0, 0),
        })
        place(title, x, y, width - tap - Components.GAP, tap)
    end
    local close = Components.button(body, {
        Name = "Close",
        Text = "X",
        Width = tap,
        OnActivated = function()
            self:Close()
        end,
    })
    place(close, x + width - tap, y, tap, tap)
    self.Selectables.close = close
    return close
end

function CatalogScreen:Cards(parent, shown, viewed, mode)
    local list = Components.cardList(parent, mode)
    for order, item in shown do
        local card = Components.card(list, item, {
            Order = order,
            Viewing = viewed ~= nil and item.Id == viewed.Id,
            SelectedLabel = self.Config.Template == "LockIn" and "LOCKED IN" or nil,
            OnActivated = function()
                self.ViewingId = item.Id
                self.Focus = "viewing"
                self:Render()
            end,
        })
        if viewed and item.Id == viewed.Id then
            self.Selectables.viewing = card
        end
    end
    return list
end

function CatalogScreen:RenderBrowser(body, width, height)
    local pad, gap, tap = Components.PAD, Components.GAP, Components.tapHeight()
    local inner = width - pad * 2
    local shown = self:Visible()
    local viewed = self:Viewed(shown)
    local wide = width >= 900
    local short = height < 620
    local statusHeight = Components.line("Label") + 4
    local y = pad

    -- controls: title and close, then tabs with the filter at the end of the row
    local closeInTabs = wide and short
    if not closeInTabs then
        self:Header(body, pad, y, inner, true)
        y += tap + gap
    end
    local filterWidth = Components.measure("SHOW: AVAILABLE", "Body").X + 36
    local tabsWidth = inner - filterWidth - gap - (closeInTabs and (tap + gap) or 0)
    local tabs = self.Config.Tabs or {}
    if #tabs > 1 then
        local strip = Components.tabStrip(body, tabs, self.Tab, function(id)
            self.Tab = id
            self.ViewingId = nil
            self:Render()
        end)
        place(strip, pad, y, tabsWidth, tap)
    end
    local filterIndex = 1
    for index, filter in CatalogScreen.Filters do
        if filter.Id == self.Filter then
            filterIndex = index
        end
    end
    local filter = Components.button(body, {
        Name = "Filter",
        Text = CatalogScreen.Filters[filterIndex].Label,
        OnActivated = function()
            self.Filter = CatalogScreen.Filters[filterIndex % #CatalogScreen.Filters + 1].Id
            self.Focus = "filter"
            self:Render()
        end,
    })
    place(filter, pad + tabsWidth + gap, y, filterWidth, tap)
    self.Selectables.filter = filter
    if closeInTabs then
        self:Header(body, pad, y, inner, false)
    end
    y += tap + gap

    local status = Components.statusLine(body, self.Status.Text, self.Status.Tone)
    place(status, pad, height - pad - statusHeight, inner, statusHeight)
    local room = height - pad - statusHeight - gap - y

    -- regions, by shape of the panel
    local cards, previewRect, detailRect, actionRect
    local hasPreview = self.Config.Preview ~= nil
    if wide and not short then
        -- desktop, tablet, console: cards beside the preview, detail and action underneath
        local upper = math.floor(room * 0.52)
        local cardsWidth = hasPreview and math.floor(inner * 0.58) or inner
        cards = place(self:Cards(body, shown, viewed, "Grid"), pad, y, cardsWidth, upper)
        previewRect = { pad + cardsWidth + gap, y, inner - cardsWidth - gap, upper }
        local lowerY, lower = y + upper + gap, room - upper - gap
        local actionWidth = 300
        detailRect = { pad, lowerY, inner - actionWidth - gap, lower }
        actionRect = { pad + inner - actionWidth, lowerY + lower - tap, actionWidth, tap }
    elseif wide then
        -- phone in landscape: wide and very short, so two columns
        local left = math.floor(inner * 0.5)
        cards = place(self:Cards(body, shown, viewed, "Grid"), pad, y, left, room)
        local rightX, rightWidth = pad + left + gap, inner - left - gap
        local previewHeight = hasPreview and math.floor(room * 0.3) or 0
        previewRect = { rightX, y, rightWidth, previewHeight }
        local detailY = y + (hasPreview and previewHeight + gap or 0)
        detailRect = { rightX, detailY, rightWidth, y + room - tap - gap - detailY }
        actionRect = { rightX, y + room - tap, rightWidth, tap }
    else
        -- portrait and Split View: one column, cards in a row that scrolls sideways
        local rowHeight = Components.cardSize().Y + 12
        cards = place(self:Cards(body, shown, viewed, "Row"), pad, y, inner, rowHeight)
        local nextY = y + rowHeight + gap
        local previewHeight = hasPreview and math.floor(room * 0.22) or 0
        previewRect = { pad, nextY, inner, previewHeight }
        nextY += hasPreview and previewHeight + gap or 0
        detailRect = { pad, nextY, inner, y + room - tap - gap - nextY }
        actionRect = { pad, y + room - tap, inner, tap }
    end
    cards.Name = "Cards"

    if not viewed then
        local empty =
            Components.label(body, "Nothing here yet.", "Body", { Name = "Empty", Color = Theme.Color.TextMuted })
        place(empty, detailRect[1], detailRect[2], detailRect[3], detailRect[4])
        return
    end
    if hasPreview and previewRect[4] > 0 then
        local preview = Components.panel(body, "Preview", Theme.Color.Panel)
        place(preview, previewRect[1], previewRect[2], previewRect[3], previewRect[4])
        -- The consumer draws the model. If it has nothing to show it returns false, and the
        -- screen says so instead of showing unrelated art.
        if self.Config.Preview(preview, viewed) == false then
            local pending = Components.label(preview, "VISUAL IN DEVELOPMENT", "Label", {
                Name = "PreviewPending",
                Color = Theme.Color.TextMuted,
                Align = Enum.TextXAlignment.Center,
                Size = UDim2.fromScale(1, 1),
            })
            pending.TextWrapped = true
        end
    end
    local detail = Components.detail(body, viewed, false)
    place(detail, detailRect[1], detailRect[2], detailRect[3], detailRect[4])
    local action = Components.actionButton(body, viewed, function(name)
        self:Act(viewed, name)
    end)
    place(action, actionRect[1], actionRect[2], actionRect[3], actionRect[4])
    self.Selectables.action = action
end

function CatalogScreen:RenderLockIn(body, width, height)
    local pad, gap, tap = Components.PAD, Components.GAP, Components.tapHeight()
    local inner = width - pad * 2
    local labelHeight = Components.line("Label") + 2
    local closed = self.EndsAt ~= nil and Components.now() >= self.EndsAt
    local y = pad

    local title = Components.label(body, self.Config.Title or "LOCK-IN", "Title", {
        Name = "ScreenTitle",
        Color = Theme.Color.Accent,
        Font = Enum.Font.GothamBlack,
        Size = UDim2.fromOffset(0, 0),
    })
    place(title, pad, y, inner * 0.5, tap)
    local clock = Components.label(body, "", "Title", {
        Name = "Countdown",
        Align = Enum.TextXAlignment.Right,
        Size = UDim2.fromOffset(0, 0),
    })
    place(clock, pad + inner * 0.5, y, inner * 0.5, tap)
    if self.EndsAt then
        Components.countdown(clock, self.EndsAt, function(left)
            if left <= 0 then
                return "MATCH LOCKED"
            end
            return ("DEPLOYING IN %.1f"):format(left)
        end)
        if not closed then
            -- redraw once at the deadline so the buttons switch off without a server message
            local deadline = self.EndsAt
            task.delay(math.max(0, deadline - Components.now()) + 0.05, function()
                if self.Gui.Enabled and self.EndsAt == deadline then
                    self:Render()
                end
            end)
        end
    end
    y += tap + 4
    local map = Components.label(body, self.MapName and ("MAP: " .. self.MapName:upper()) or "", "Label", {
        Name = "Map",
        Color = Theme.Color.TextMuted,
        Size = UDim2.fromOffset(0, 0),
    })
    place(map, pad, y, inner, labelHeight)
    y += labelHeight + gap

    -- Only what can be used, and never a purchase: this countdown is not a sales surface.
    local shown = {}
    for _, item in self:Visible() do
        if item.Action ~= "Buy" and item.Action ~= "Pending" then
            table.insert(shown, item)
        end
    end
    local viewed = self:Viewed(shown)
    local rowHeight = Components.cardSize().Y + 12
    place(self:Cards(body, shown, viewed, "Row"), pad, y, inner, rowHeight)
    y += rowHeight + gap

    local statusHeight = Components.line("Label") + 4
    local status = Components.statusLine(body, self.Status.Text, self.Status.Tone)
    place(status, pad, height - pad - statusHeight, inner, statusHeight)
    if not viewed then
        return
    end
    local actionWidth = math.min(300, inner * 0.4)
    local lower = height - pad - statusHeight - gap - y
    local detail = Components.detail(body, viewed, true)
    place(detail, pad, y, inner - actionWidth - gap, lower)

    local shownItem = viewed
    if closed then
        -- display only; the server has already taken its snapshot
        shownItem = table.clone(viewed)
        shownItem.Action = "MatchLocked"
    end
    local action = Components.actionButton(body, shownItem, function(name)
        self:Act(viewed, name)
    end)
    place(action, pad + inner - actionWidth, y + lower - tap, actionWidth, tap)
    self.Selectables.action = action
end

function CatalogScreen:RenderTrack(body, width, height)
    local pad, gap, tap = Components.PAD, Components.GAP, Components.tapHeight()
    local inner = width - pad * 2
    local labelSize = Components.textSize("Label")
    local labelHeight = Components.line("Label") + 2
    local track = self.Track
    local y = pad
    self:Header(body, pad, y, inner, true)
    y += tap + 4
    local statusHeight = Components.line("Label") + 4
    local status = Components.statusLine(body, self.Status.Text, self.Status.Tone)
    place(status, pad, height - pad - statusHeight, inner, statusHeight)
    if not track then
        return
    end

    local subtitle = Components.label(body, track.Subtitle, "Label", {
        Name = "Subtitle",
        Color = Theme.Color.TextMuted,
        Size = UDim2.fromOffset(0, 0),
    })
    place(subtitle, pad, y, inner * 0.6, labelHeight)
    if track.EndsAt then
        local ends = Components.label(body, "", "Label", {
            Name = "Ends",
            Color = Theme.Color.TextMuted,
            Align = Enum.TextXAlignment.Right,
            Size = UDim2.fromOffset(0, 0),
        })
        place(ends, pad + inner * 0.6, y, inner * 0.4, labelHeight)
        Components.countdown(ends, track.EndsAt, function(left)
            return left > 0 and ("ENDS IN " .. Components.duration(left)) or "SEASON ENDED"
        end)
    end
    y += labelHeight + 4
    local level = Components.label(body, ("TIER %d"):format(track.Level), "Body", {
        Name = "Level",
        Size = UDim2.fromOffset(0, 0),
    })
    local levelWidth = Components.measure("TIER 000", "Body").X + 8
    place(level, pad, y, levelWidth, labelHeight)
    local bar = Components.progress(body, track.Progress, "Accent")
    place(bar, pad + levelWidth + gap, y + (labelHeight - 12) / 2, inner - levelWidth - gap, 12)
    y += labelHeight + gap

    -- tiers: a row label column, then one column per tier scrolling sideways
    local actionY = height - pad - statusHeight - gap - tap
    local rowsHeight = actionY - gap - y
    local cellHeight = math.max(tap, math.floor((rowsHeight - labelHeight - gap * 2 - 8) / 2))
    local sideWidth = Components.measure("PREMIUM", "Label").X + 12
    for index, name in { "FREE", "PREMIUM" } do
        local side = Components.label(body, name, "Label", {
            Name = "Row" .. name,
            Color = Theme.Color.TextMuted,
            Size = UDim2.fromOffset(0, 0),
        })
        place(side, pad, y + labelHeight + gap + (index - 1) * (cellHeight + gap), sideWidth, cellHeight)
    end
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Tiers"
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Theme.Color.TextMuted
    scroll.ScrollingDirection = Enum.ScrollingDirection.X
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    scroll.CanvasSize = UDim2.new()
    scroll.Parent = body
    place(scroll, pad + sideWidth + gap, y, inner - sideWidth - gap, rowsHeight)
    Components.list(scroll, Enum.FillDirection.Horizontal, gap)
    local columnWidth = math.ceil(Components.textSize("Body") * 11 * Components.growth())
    for _, tier in track.Tiers do
        local reached = tier.Tier <= track.Level
        local column = Components.frame(scroll, "Tier" .. tier.Tier)
        column.LayoutOrder = tier.Tier
        column.Size = UDim2.fromOffset(columnWidth, labelHeight + (cellHeight + gap) * 2)
        local number = Components.label(column, ("TIER %d"):format(tier.Tier), "Label", {
            Name = "Number",
            Color = reached and Theme.Color.Accent or Theme.Color.TextMuted,
            Align = Enum.TextXAlignment.Center,
            Size = UDim2.fromOffset(0, 0),
        })
        place(number, 0, 0, columnWidth, labelHeight)
        if reached then
            -- reached tiers carry a bar as well as the accent colour
            local mark = Components.frame(column, "ReachedMark")
            mark.BackgroundTransparency = 0
            mark.BackgroundColor3 = Theme.Color.Accent
            place(mark, 8, labelHeight + 2, columnWidth - 16, 3)
        end
        for index, row in { "Free", "Premium" } do
            local reward = tier[row]
            local cellY = labelHeight + gap + (index - 1) * (cellHeight + gap)
            if reward then
                local stateSpec = CatalogItem.RewardStates[reward.State]
                local claimable = reward.State == "Claimable"
                local cell = Components.button(column, {
                    Name = row .. "Reward",
                    Text = reward.Title .. "\n" .. stateSpec.Label,
                    Style = claimable and "Primary" or "Secondary",
                    Enabled = claimable,
                    OnActivated = function()
                        self.Focus = "action"
                        if self.Config.OnAction then
                            self.Config.OnAction({ Tier = tier.Tier, Row = row, Reward = reward }, "Claim")
                        end
                    end,
                })
                cell.TextSize = labelSize
                cell.TextWrapped = true
                cell.TextTruncate = Enum.TextTruncate.None
                if reward.State == "Claimed" then
                    cell.TextColor3 = Theme.Color.Good
                end
                place(cell, 0, cellY, columnWidth, cellHeight)
                if claimable and not self.Selectables.viewing then
                    self.Selectables.viewing = cell
                end
            else
                local blank = Components.panel(column, row .. "Empty", Theme.Color.Panel)
                place(blank, 0, cellY, columnWidth, cellHeight)
            end
        end
    end

    local action = Components.actionButton(body, {
        Id = track.Id,
        Title = track.Title,
        Action = track.Action,
        Price = track.Price,
    }, function(name)
        self:Act({ Id = track.Id, Title = track.Title, Price = track.Price }, name)
    end)
    if track.Action == "Buy" then
        action.Text = "GET PREMIUM  ·  " .. Components.price(track.Price)
    end
    local actionWidth = math.min(360, inner)
    place(action, pad + inner - actionWidth, actionY, actionWidth, tap)
    self.Selectables.action = action
end

return CatalogScreen
