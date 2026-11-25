-- LobbyShell: the frame every lobby screen opens from.
--
--   Nav      the destinations, one of them the dominant PLAY. Destinations marked Fold collapse
--            into a single MORE button when the row does not fit.
--   Wallet   level and currencies in one pressable readout.
--   Queue    mode, team, time waited and LEAVE. It is drawn on its own layer above the modals,
--            so it is still there while the player browses kits or the shop.
--   Toasts   short results ("Saved.", "Could not join") that do not need a screen of their own.
--
-- Where things go follows the reserved zones in UI/Screen. On touch the bottom edge belongs to
-- the thumbstick, the jump cluster and the hotbar, so everything sits along the top. With a
-- mouse or a controller the nav sits bottom-centre above the hotbar and the readouts along the
-- top. The shell never sits in a thumb zone or on the hotbar; tools/check_ui.luau checks that
-- on seven screen sizes.
--
--   local shell = LobbyShell.new({
--       Name = "LobbyShell",
--       Destinations = {
--           { Id = "Play", Label = "PLAY", Primary = true },
--           { Id = "Loadout", Label = "LOADOUT" },
--           { Id = "Profile", Label = "PROFILE", Fold = true },
--       },
--       OnNavigate = function(id, folded) ... end,   -- "More" comes with the folded list
--       OnLeaveQueue = function() ... end,
--       OnWallet = function() ... end,               -- leave out and the wallet is a readout
--   })
--   shell:SetProfile({ Level = 12, Progress = 0.4, Currencies = { { Id = "Credits", Amount = 1250 } } })
--   shell:SetQueue({ State = "Searching", Mode = "CONVERGENCE", Team = "RED", Since = serverTime })
--   shell:SetDots({ Shop = 2 })   shell:SetActive("Loadout")   shell:Toast("Saved.", "Good")
--   shell:Show()   shell:Hide()
--
-- Like the catalog screens it draws what it is given and nothing else: the queue strip appears
-- when the server says the player is queued, never because a button was pressed.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Components = require(script.Parent.Components)
local Screen = require(script.Parent.Screen)
local ScreenStack = require(script.Parent.ScreenStack)
local Theme = require(script.Parent.Theme)

local LobbyShell = {}
LobbyShell.__index = LobbyShell

LobbyShell.MAX_DESTINATIONS = 6
LobbyShell.TOAST_SECONDS = 4
LobbyShell.MAX_TOASTS = 3
-- Screen pixels above the bottom inset that Roblox's backpack hotbar owns with a mouse.
LobbyShell.HOTBAR_CLEARANCE = 110

local SEPARATOR = "  \u{00B7}  "

local function place(instance, x, y, width, height)
    instance.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
    instance.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
    return instance
end

local function grouped(amount)
    local digits = tostring(math.floor(amount))
    local text = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if text:sub(1, 1) == "," then
        text = text:sub(2)
    end
    return text
end

local function layer(name, order)
    local gui = Screen.newScreenGui(name, order)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    -- One frame in design pixels covering the screen. Its size is in scale and divided by the
    -- UIScale, so it comes out at exactly the safe area whatever the device.
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.Parent = gui
    Screen.autoScale(panel)
    return gui, panel
end

function LobbyShell.new(config)
    assert(#config.Destinations >= 1, "LobbyShell: at least one destination")
    assert(#config.Destinations <= LobbyShell.MAX_DESTINATIONS, "LobbyShell: six destinations at most")
    local primaries = 0
    for _, destination in config.Destinations do
        primaries += destination.Primary and 1 or 0
    end
    assert(primaries == 1, "LobbyShell: exactly one destination is Primary")

    local self = setmetatable({}, LobbyShell)
    self.Config = config
    self.Dots = {}
    self.Toasts = {}
    self.Shown = false
    self.Modal = false
    self.Focus = nil
    self.Selectables = {}
    self.MainGui, self.Main = layer(config.Name, Screen.Layers.Lobby)
    self.TopGui, self.Top = layer(config.Name .. "Status", Screen.Layers.Persistent)

    local function redraw()
        self:Render()
    end
    self._stopScreen = Screen.onChange(redraw)
    self._stopSettings = Components.onSettingsChanged(redraw)
    -- A modal on top hides the nav and wallet; the queue strip stays.
    self._stopStack = ScreenStack.onChange(function(depth)
        self:SetModal(depth > 0)
    end)
    return self
end

-- ===== state =====

-- nil while the profile has not arrived: the wallet reads LOADING and cannot be pressed.
function LobbyShell:SetProfile(profile)
    self.Profile = profile
    self:Render()
end

-- nil when the player is not queued. State is "Searching" or "Found".
function LobbyShell:SetQueue(queue)
    self.Queue = queue
    self:Render()
end

-- counts by destination id; nil or zero clears one.
function LobbyShell:SetDots(dots)
    self.Dots = dots or {}
    self:Render()
end

function LobbyShell:SetActive(id)
    self.Active = id
    self:Render()
end

function LobbyShell:SetModal(modal)
    if self.Modal == modal then
        return
    end
    self.Modal = modal
    self:Render()
end

function LobbyShell:Toast(text, tone)
    local toast = { Text = text, Tone = tone or "Text" }
    table.insert(self.Toasts, toast)
    while #self.Toasts > LobbyShell.MAX_TOASTS do
        table.remove(self.Toasts, 1)
    end
    task.delay(LobbyShell.TOAST_SECONDS, function()
        local at = table.find(self.Toasts, toast)
        if at then
            table.remove(self.Toasts, at)
            self:Render()
        end
    end)
    self:Render()
end

function LobbyShell:Show()
    self.Shown = true
    self:Render()
end

function LobbyShell:Hide()
    self.Shown = false
    self.MainGui.Enabled = false
    self.TopGui.Enabled = false
    self:Reserve(0)
end

function LobbyShell:Destroy()
    self:Hide()
    self._stopScreen()
    self._stopSettings()
    self._stopStack()
    self.MainGui:Destroy()
    self.TopGui:Destroy()
end

-- ===== measuring =====

function LobbyShell:Extent(state)
    local ok, size = pcall(function()
        return self.MainGui.AbsoluteSize
    end)
    if ok and size and size.X > 0 and size.Y > 0 then
        return size.X / state.Scale, size.Y / state.Scale
    end
    return state.Viewport.X / state.Scale, state.Viewport.Y / state.Scale
end

function LobbyShell:Reserve(pixels)
    if Components.Reserve.Top ~= pixels then
        Components.Reserve.Top = pixels
        ScreenStack.refresh()
    end
end

-- The destinations to draw: all of them, or with the Fold ones replaced by MORE.
function LobbyShell:NavItems(fold)
    local items, folded = {}, {}
    for _, destination in self.Config.Destinations do
        if fold and destination.Fold then
            table.insert(folded, destination.Id)
        else
            table.insert(items, destination)
        end
    end
    if #folded > 0 then
        local dots = 0
        for _, id in folded do
            dots += self.Dots[id] or 0
        end
        table.insert(items, { Id = "More", Label = "MORE", Folded = folded, Dots = dots })
    end
    return items
end

local function navWidths(items, tap)
    local widths, total = {}, 0
    for index, item in items do
        local width = math.max(Components.measure(item.Label, "Body").X + Components.textSize("Body") * 2.2, tap * 1.6)
        if item.Primary then
            width *= 1.3
        end
        widths[index] = math.ceil(width)
        total += widths[index]
    end
    return widths, total + math.max(0, #items - 1) * Components.GAP
end

function LobbyShell:WalletText(compact)
    local profile = self.Profile
    if not profile then
        return "LOADING..."
    end
    local parts = {}
    if not compact then
        table.insert(parts, ("LEVEL %d"):format(profile.Level))
    end
    for index, currency in profile.Currencies or {} do
        if compact and index > 1 then
            break
        end
        table.insert(parts, grouped(currency.Amount) .. " " .. currency.Id:upper())
    end
    if #parts == 0 then
        return ("LEVEL %d"):format(profile.Level)
    end
    return table.concat(parts, SEPARATOR)
end

function LobbyShell:QueueText(elapsed)
    local queue = self.Queue
    if queue.State == "Found" then
        return "MATCH FOUND" .. SEPARATOR .. queue.Mode
    end
    local parts = { "IN QUEUE", queue.Mode }
    if queue.Team then
        table.insert(parts, queue.Team)
    end
    table.insert(parts, Components.duration(elapsed))
    return table.concat(parts, SEPARATOR)
end

-- ===== rendering =====

function LobbyShell:Render()
    if not self.Shown then
        return
    end
    local state = Screen.get()
    local scale = state.Scale
    local gamepad = Components.usingGamepad()
    for _, panel in { self.Main, self.Top } do
        panel.Size = UDim2.fromScale(1 / scale, 1 / scale)
        for _, child in panel:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
    end
    self.MainGui.Enabled = not self.Modal
    self.TopGui.Enabled = true
    if self.Config.HidePlayerList ~= false then
        -- the wallet and queue strip use the top edge the player list would cover
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        end)
    end
    local main = Components.frame(self.Main, "Body")
    main.Size = UDim2.fromScale(1, 1)
    local status = Components.frame(self.Top, "Body")
    status.Size = UDim2.fromScale(1, 1)
    self.Selectables = {}

    local width, height = self:Extent(state)
    local gap, tap = Components.GAP, Components.tapHeight()
    -- rounded inwards, so a piece placed on an inset is never a fraction of a pixel outside it
    local left, right = math.ceil(state.Insets.Left / scale), math.ceil(state.Insets.Right / scale)
    local top, bottom = math.ceil(state.Insets.Top / scale), math.ceil(state.Insets.Bottom / scale)
    local avail = width - left - right
    local stripHeight = tap + 8
    self.Layout = { Width = width, Height = height }

    -- The queue strip's natural width, measured with the widest time it will show.
    local stripWidth, leaveWidth = 0, 0
    if self.Queue then
        leaveWidth = self.Queue.State == "Found" and 0 or Components.measure("LEAVE", "Body").X + 32
        stripWidth = 12 + Components.measure(self:QueueText(5999), "Body").X + 12 + leaveWidth + 4
    end

    if self.Modal then
        -- only the queue strip, at the top; the modal panel starts below it
        if self.Queue then
            local w = math.min(stripWidth, avail)
            self:DrawQueue(status, (width - w) / 2, top, w, stripHeight, leaveWidth)
            self:Reserve(math.ceil((stripHeight + gap) * scale))
        else
            self:Reserve(0)
        end
        return
    end
    self:Reserve(0)

    local fullWallet = Components.measure(self:WalletText(false), "Body").X + 32
    local compactWallet = Components.measure(self:WalletText(true), "Body").X + 32
    local items, widths, navWidth = self:NavItems(false), nil, 0
    widths, navWidth = navWidths(items, tap)
    local nextY
    local walletLeftEdge = width

    if state.Touch then
        -- top edge only: nav on the right, wallet on the left
        local walletWidth, walletCompact, walletRow = fullWallet, false, 1
        if navWidth + gap + fullWallet > avail then
            items = self:NavItems(true)
            widths, navWidth = navWidths(items, tap)
            if navWidth + gap + fullWallet > avail then
                walletWidth, walletCompact = compactWallet, true
                if navWidth + gap + compactWallet > avail then
                    walletRow = 2
                end
            end
        end
        if navWidth > avail then
            -- still too wide: share the row equally (the gate fails this if a share is too small)
            local share = math.floor((avail - (#items - 1) * gap) / #items)
            for index in widths do
                widths[index] = share
            end
            navWidth = avail
        end
        self:DrawNav(main, items, widths, width - right - navWidth, top, tap)
        local rowTwo = top + tap + gap
        walletWidth = math.min(walletWidth, avail)
        self:DrawWallet(main, left, walletRow == 1 and top or rowTwo, walletWidth, tap, walletCompact)
        nextY = rowTwo + (walletRow == 2 and tap + gap or 0)
        if self.Queue then
            local room = avail - (walletRow == 2 and walletWidth + gap or 0)
            local y = rowTwo
            if stripWidth > room and walletRow == 2 then
                y, room = rowTwo + tap + gap, avail
            end
            local w = math.min(stripWidth, room)
            self:DrawQueue(status, width - right - w, y, w, stripHeight, leaveWidth)
            nextY = math.max(nextY, y + stripHeight + gap)
        end
    else
        -- readouts along the top, nav bottom-centre above the hotbar
        local walletCompact = fullWallet > avail * 0.45
        local walletWidth = math.min(walletCompact and compactWallet or fullWallet, avail)
        local walletX = width - right - walletWidth
        self:DrawWallet(main, walletX, top, walletWidth, tap, walletCompact)
        walletLeftEdge = walletX
        nextY = top
        if self.Queue then
            local w = math.min(stripWidth, avail)
            local x, y = (width - w) / 2, top
            if x + w > walletX - gap then
                x = walletX - gap - w
            end
            if x < left then
                x, y = (width - w) / 2, top + tap + gap
            end
            self:DrawQueue(status, x, y, w, stripHeight, leaveWidth)
            nextY = y + stripHeight + gap
        end
        if navWidth > avail then
            items = self:NavItems(true)
            widths, navWidth = navWidths(items, tap)
        end
        if navWidth > avail then
            local share = math.floor((avail - (#items - 1) * gap) / #items)
            for index in widths do
                widths[index] = share
            end
            navWidth = avail
        end
        local navY = height - bottom - LobbyShell.HOTBAR_CLEARANCE / scale - tap
        self:DrawNav(main, items, widths, (width - navWidth) / 2, navY, tap)
    end

    if #self.Toasts > 0 then
        local toastWidth = math.min(avail, math.ceil(Components.textSize("Body") * 30 * Components.growth()))
        local centre = width / 2
        if state.Touch and state.ThumbLeft and state.ThumbRight then
            -- on touch, toasts sit in the gap between the thumb zones
            local from, to = state.ThumbLeft[3] * width + gap, state.ThumbRight[1] * width - gap
            toastWidth = math.min(toastWidth, to - from)
            centre = (from + to) / 2
        elseif centre + toastWidth / 2 > walletLeftEdge - gap then
            nextY = math.max(nextY, top + tap + gap) -- clear of the wallet
        end
        self:DrawToasts(status, centre - toastWidth / 2, nextY, toastWidth)
    end

    if gamepad then
        GuiService.SelectedObject = self.Selectables[self.Focus] or self.Selectables.primary
    end
end

function LobbyShell:DrawNav(parent, items, widths, x, y, tap)
    local nav = Components.frame(parent, "Nav")
    local total = 0
    for index, item in items do
        local button = Components.button(nav, {
            Name = "Nav_" .. item.Id,
            Text = item.Label,
            Style = item.Primary and "Primary" or "Secondary",
            Width = widths[index],
            OnActivated = function()
                self.Focus = item.Id
                if self.Config.OnNavigate then
                    self.Config.OnNavigate(item.Id, item.Folded)
                end
            end,
        })
        place(button, total, 0, widths[index], tap)
        if item.Primary then
            button.Font = Enum.Font.GothamBlack
            Components.stroke(button, Theme.Color.Text, 1)
            self.Selectables.primary = button
        else
            button.BackgroundTransparency = Components.surface(Theme.Transparency.Panel)
        end
        local active = self.Active == item.Id
        if active and not item.Primary then
            button.BackgroundColor3 = Theme.Color.PanelSelected
            local mark = Components.frame(button, "ActiveMark")
            mark.BackgroundTransparency = 0
            mark.BackgroundColor3 = Theme.Color.Accent
            mark.AnchorPoint = Vector2.new(0.5, 1)
            mark.Position = UDim2.new(0.5, 0, 1, -4)
            mark.Size = UDim2.new(1, -20, 0, 4)
        end
        button:SetAttribute("Active", active)
        Components.dot(button, item.Dots or self.Dots[item.Id])
        self.Selectables[item.Id] = button
        total += widths[index] + Components.GAP
    end
    place(nav, x, y, total - Components.GAP, tap)
    return nav
end

function LobbyShell:DrawWallet(parent, x, y, width, tap, compact)
    local pressable = self.Profile ~= nil and self.Config.OnWallet ~= nil
    local wallet = Components.button(parent, {
        Name = "Wallet",
        Text = self:WalletText(compact),
        Enabled = pressable,
        OnActivated = function()
            self.Focus = "wallet"
            self.Config.OnWallet()
        end,
    })
    place(wallet, x, y, width, tap)
    wallet.BackgroundTransparency = Components.surface(Theme.Transparency.Panel)
    if self.Profile then
        -- a readout is still meant to be read: full-strength text even when it cannot be pressed
        wallet.TextColor3 = Theme.Color.Text
        wallet.BackgroundColor3 = Theme.Color.Panel
        if self.Profile.Progress then
            local bar = Components.progress(wallet, self.Profile.Progress, "Accent")
            bar.Name = "LevelProgress"
            bar.AnchorPoint = Vector2.new(0.5, 1)
            bar.Position = UDim2.new(0.5, 0, 1, -3)
            bar.Size = UDim2.new(1, -16, 0, 3)
        end
    end
    wallet:SetAttribute("Compact", compact)
    self.Selectables.wallet = wallet
    return wallet
end

function LobbyShell:DrawQueue(parent, x, y, width, height, leaveWidth)
    local queue = self.Queue
    local found = queue.State == "Found"
    local strip = Components.panel(parent, "Queue", Theme.Color.Panel)
    strip.BackgroundTransparency = Components.surface(Theme.Transparency.Panel)
    Components.stroke(strip, found and Theme.Color.Good or Theme.Color.Accent, 2)
    place(strip, x, y, width, height)
    strip:SetAttribute("State", queue.State)
    local text = Components.label(strip, "", "Body", {
        Name = "QueueText",
        Color = found and Theme.Color.Good or Theme.Color.Text,
        Size = UDim2.fromOffset(0, 0),
    })
    place(text, 12, 0, width - 24 - leaveWidth - (leaveWidth > 0 and 4 or 0), height)
    if found or not queue.Since then
        text.Text = self:QueueText(0)
    else
        Components.elapsed(text, queue.Since, function(elapsed)
            return self:QueueText(elapsed)
        end)
    end
    if leaveWidth > 0 then
        local leave = Components.button(strip, {
            Name = "LeaveQueue",
            Text = "LEAVE",
            Width = leaveWidth,
            Enabled = self.Config.OnLeaveQueue ~= nil,
            OnActivated = function()
                self.Focus = "leave"
                self.Config.OnLeaveQueue()
            end,
        })
        place(leave, width - leaveWidth - 4, 4, leaveWidth, height - 8)
        self.Selectables.leave = leave
    end
    return strip
end

function LobbyShell:DrawToasts(parent, x, y, width)
    local line = Components.line("Body")
    local toasts = Components.frame(parent, "Toasts")
    local offset = 0
    for index, toast in self.Toasts do
        local shown = toast.Text
        if toast.Tone == "Danger" then
            shown = "!  " .. shown -- errors carry a mark as well as a colour
        end
        -- a narrow screen wraps the message instead of cutting it off
        local lines = math.clamp(math.ceil(Components.measure(shown, "Body").X / (width - 20)), 1, 3)
        local rowHeight = line * lines + 14
        local row = Components.panel(toasts, "Toast" .. index, Theme.Color.Panel)
        row.BackgroundTransparency = Components.surface(Theme.Transparency.Panel)
        place(row, 0, offset, width, rowHeight)
        local text = Components.label(row, shown, "Body", {
            Name = "ToastText",
            Color = Components.tone(toast.Tone),
            Align = Enum.TextXAlignment.Center,
            Size = UDim2.fromOffset(0, 0),
        })
        place(text, 10, 0, width - 20, rowHeight)
        offset += rowHeight + 6
    end
    place(toasts, x, y, width, offset - 6)
    return toasts
end

return LobbyShell
