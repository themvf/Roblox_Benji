-- Components: the shared widgets every catalog-style screen is built from.
--
-- Screen says where things go and Theme says how they look; this is the layer above them that
-- actually builds a button, a card or a detail panel, so a new screen is data plus a template
-- (client/UI/CatalogScreen) and not another controller with its own copy of `button()`.
--
-- What each widget guarantees, so a screen built from them cannot get it wrong:
--   * text sizes come from the four-step Theme ramp through Theme.textSize (phone / console floor)
--   * everything pressable is at least Screen.MIN_TAP tall after scaling
--   * state is never colour alone: access is a text label, the selected item carries a tag and a
--     thicker outline, the active tab an underline
--   * disabled controls are not selectable, so controller focus cannot land on them
--
-- Sizes are design pixels. Widgets expect to live under a panel that Screen.autoScale drives.
-- tools/check_ui.luau builds every widget offline and fails if a raw widget appears in a
-- controller that is not already on its baseline.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CatalogItem = require(ReplicatedStorage.Shared.CatalogItem)
local Screen = require(script.Parent.Screen)
local Theme = require(script.Parent.Theme)

local Components = {}

Components.PAD = 16
Components.GAP = 10

-- Screen pixels at the top of the screen that a persistent strip (the queue status in
-- UI/LobbyShell) owns while a modal is open. Modal panels start below it.
Components.Reserve = { Top = 0 }

-- ===== the player's Roblox accessibility settings =====
-- Settings > Accessibility in the Roblox menu. Read here so every screen built from these
-- widgets honours them; a controller never reads GuiService for this itself.

local function setting(name, fallback)
    local ok, value = pcall(function()
        return GuiService[name]
    end)
    if ok and value ~= nil then
        return value
    end
    return fallback
end

function Components.reducedMotion()
    return setting("ReducedMotionEnabled", false) == true
end

-- Duration for a tween: zero when the player asked for reduced motion.
function Components.motion(seconds)
    return Components.reducedMotion() and 0 or seconds
end

-- Background transparency for a surface. The player's Background Transparency setting runs
-- from 1 (as designed) to 0 (fully opaque); Roblox's guidance is to multiply by it.
function Components.surface(transparency)
    local preferred = setting("PreferredTransparency", 1)
    if type(preferred) ~= "number" then
        preferred = 1
    end
    return transparency * math.clamp(preferred, 0, 1)
end

-- Run `fn` when any of the three settings changes. Returns a function that stops it.
function Components.onSettingsChanged(fn)
    local connections = {}
    for _, name in { "ReducedMotionEnabled", "PreferredTransparency", "PreferredTextSize" } do
        pcall(function()
            table.insert(connections, GuiService:GetPropertyChangedSignal(name):Connect(fn))
        end)
    end
    return function()
        for _, connection in connections do
            connection:Disconnect()
        end
    end
end

-- True while the player is driving the menus with a controller. A redraw destroys the selected
-- object, so screens ask this before rebuilding and put the selection back afterwards.
function Components.usingGamepad()
    if Screen.get().Class == "Console" or GuiService.SelectedObject ~= nil then
        return true
    end
    local ok, last = pcall(function()
        return UserInputService:GetLastInputType()
    end)
    return ok and last ~= nil and last.Name:sub(1, 7) == "Gamepad"
end

-- ===== measurements =====

function Components.textSize(step)
    return math.floor(Theme.textSize(Theme.Type[step]) + 0.5)
end

-- Size of one line of `text` as the engine will draw it. The player's Text Size setting makes
-- the engine draw text larger than TextSize says, and TextService reports the enlarged size,
-- so boxes are sized from this and never from TextSize arithmetic.
function Components.measure(text, step, font)
    local size = Components.textSize(step or "Body")
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, font or Enum.Font.GothamBold, Vector2.new(100000, 100000))
    end)
    if ok and bounds then
        return Vector2.new(math.ceil(bounds.X), math.ceil(bounds.Y))
    end
    return Vector2.new(math.ceil(#text * size * 0.62), math.ceil(size * 1.2))
end

-- Height of one line of text at a ramp step.
function Components.line(step)
    return Components.measure("Ag", step).Y
end

-- How much larger than designed the engine is drawing text (1 at the default setting).
function Components.growth()
    return math.max(1, Components.line("Body") / math.ceil(Components.textSize("Body") * 1.2))
end

-- Height in design pixels that is still 44pt on a touch screen once the panel is scaled down,
-- and never less than a line of body text plus its padding.
function Components.tapHeight()
    local state = Screen.get()
    local tap = Screen.MIN_TAP
    if state.Touch then
        tap = math.ceil(Screen.MIN_TAP / state.Scale)
    end
    return math.max(tap, Components.line("Body") + 14)
end

function Components.cardSize()
    local body, label = Components.line("Body"), Components.line("Label")
    local width = math.ceil(Components.textSize("Body") * 15 * Components.growth())
    local height = 12 + body * 2 + 4 + label + 8 + (label + 6) + 12
    return Vector2.new(width, math.max(height, Components.tapHeight()))
end

function Components.tone(name)
    return Theme.Color[name] or Theme.Color.Accent
end

-- ===== formatting =====

function Components.duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days, hours = seconds // 86400, (seconds % 86400) // 3600
    local minutes = (seconds % 3600) // 60
    if days > 0 then
        return ("%dD %02dH"):format(days, hours)
    elseif hours > 0 then
        return ("%dH %02dM"):format(hours, minutes)
    end
    return ("%d:%02d"):format(minutes, seconds % 60)
end

function Components.price(price)
    if not price then
        return ""
    end
    local digits = tostring(math.floor(price.Amount))
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then
        grouped = grouped:sub(2)
    end
    return grouped .. " " .. price.Currency:upper()
end

-- One line saying why and for how long: rotation time, price or the reason it is unavailable.
function Components.accessLine(item, now)
    if item.Access == "Trial" and item.EndsAt then
        return "FREE FOR " .. Components.duration(item.EndsAt - now)
    elseif item.Action == "Buy" and item.Price then
        return "UNLOCK FOR " .. Components.price(item.Price)
    elseif item.Reason then
        return item.Reason
    end
    return ""
end

function Components.now()
    return Workspace:GetServerTimeNow()
end

-- ===== decoration =====

function Components.corner(instance, radius)
    local ui = Instance.new("UICorner")
    ui.CornerRadius = UDim.new(0, radius or 10)
    ui.Parent = instance
    return ui
end

function Components.stroke(instance, color, thickness)
    local ui = Instance.new("UIStroke")
    ui.Color = color
    ui.Thickness = thickness or 1
    ui.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ui.Parent = instance
    return ui
end

function Components.pad(instance, px)
    local ui = Instance.new("UIPadding")
    ui.PaddingLeft = UDim.new(0, px)
    ui.PaddingRight = UDim.new(0, px)
    ui.PaddingTop = UDim.new(0, px)
    ui.PaddingBottom = UDim.new(0, px)
    ui.Parent = instance
    return ui
end

function Components.list(instance, direction, gap)
    local ui = Instance.new("UIListLayout")
    ui.FillDirection = direction or Enum.FillDirection.Vertical
    ui.SortOrder = Enum.SortOrder.LayoutOrder
    ui.Padding = UDim.new(0, gap or Components.GAP)
    ui.Parent = instance
    return ui
end

-- ===== primitives =====

function Components.frame(parent, name)
    local ui = Instance.new("Frame")
    ui.Name = name or "Frame"
    ui.BackgroundTransparency = 1
    ui.BorderSizePixel = 0
    ui.Parent = parent
    return ui
end

function Components.panel(parent, name, color)
    local ui = Components.frame(parent, name)
    ui.BackgroundTransparency = 0
    ui.BackgroundColor3 = color or Theme.Color.PanelHigh
    Components.corner(ui, 12)
    return ui
end

-- props: Color, Font, Align, Lines (fixed height, truncated), Size (overrides the default
-- full-width, grow-downwards label), Order.
function Components.label(parent, text, step, props)
    props = props or {}
    local size = Components.textSize(step or "Body")
    local ui = Instance.new("TextLabel")
    ui.Name = props.Name or "Label"
    ui.BackgroundTransparency = 1
    ui.BorderSizePixel = 0
    ui.Text = text
    ui.TextSize = size
    ui.TextColor3 = props.Color or Theme.Color.Text
    ui.Font = props.Font or Enum.Font.GothamBold
    ui.TextXAlignment = props.Align or Enum.TextXAlignment.Left
    ui.TextYAlignment = Enum.TextYAlignment.Top
    ui.TextWrapped = true
    ui.LayoutOrder = props.Order or 0
    if props.Size then
        ui.Size = props.Size
        ui.TextYAlignment = Enum.TextYAlignment.Center
        ui.TextTruncate = Enum.TextTruncate.AtEnd
    elseif props.Lines then
        ui.Size = UDim2.new(1, 0, 0, Components.line(step or "Body") * props.Lines)
        ui.TextTruncate = Enum.TextTruncate.AtEnd
    else
        ui.Size = UDim2.new(1, 0, 0, 0)
        ui.AutomaticSize = Enum.AutomaticSize.Y
    end
    ui.Parent = parent
    return ui
end

-- props: Text, Style ("Primary" | "Secondary"), Enabled, Width (design px; nil fills the
-- parent), OnActivated, Name, Order. Height is always the tap height.
function Components.button(parent, props)
    local enabled = props.Enabled ~= false
    local primary = props.Style == "Primary"
    local ui = Instance.new("TextButton")
    ui.Name = props.Name or "Button"
    ui.AutoButtonColor = enabled
    ui.Active = enabled
    ui.Selectable = enabled
    ui.BorderSizePixel = 0
    ui.Text = props.Text or ""
    ui.Font = Enum.Font.GothamBold
    ui.TextSize = Components.textSize("Body")
    ui.TextTruncate = Enum.TextTruncate.AtEnd
    ui.LayoutOrder = props.Order or 0
    ui.Size = UDim2.new(props.Width and 0 or 1, props.Width or 0, 0, Components.tapHeight())
    if not enabled then
        ui.BackgroundColor3 = Theme.Color.Track
        ui.TextColor3 = Theme.Color.TextMuted
    elseif primary then
        ui.BackgroundColor3 = Theme.Color.Accent
        ui.TextColor3 = Theme.Color.Panel
    else
        ui.BackgroundColor3 = Theme.Color.PanelHigh
        ui.TextColor3 = Theme.Color.Text
    end
    Components.corner(ui, 10)
    if not enabled then
        -- a dashed look is not available; an outline marks "this is a state, not a button"
        Components.stroke(ui, Theme.Color.PanelSelected, 1)
    end
    ui:SetAttribute("Enabled", enabled)
    ui.Parent = parent
    if enabled and props.OnActivated then
        ui.Activated:Connect(props.OnActivated)
    end
    return ui
end

-- A small text tag. `filled` is the strong form (dark text on the tone colour).
function Components.badge(parent, text, toneName, filled)
    local tone = Components.tone(toneName)
    local size = Components.textSize("Label")
    local ui = Instance.new("TextLabel")
    ui.Name = "Badge"
    ui.BorderSizePixel = 0
    ui.Text = text
    ui.Font = Enum.Font.GothamBlack
    ui.TextSize = size
    ui.AutomaticSize = Enum.AutomaticSize.X
    ui.Size = UDim2.fromOffset(0, Components.line("Label") + 6)
    ui.BackgroundColor3 = filled and tone or Theme.Color.Panel
    ui.TextColor3 = filled and Theme.Color.Panel or tone
    Components.corner(ui, 6)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = ui
    ui.Parent = parent
    return ui
end

function Components.progress(parent, fraction, toneName)
    local track = Components.frame(parent, "Progress")
    track.BackgroundTransparency = 0
    track.BackgroundColor3 = Theme.Color.Track
    track.Size = UDim2.new(1, 0, 0, 12)
    Components.corner(track, 6)
    local fill = Components.frame(track, "Fill")
    fill.BackgroundTransparency = 0
    fill.BackgroundColor3 = Components.tone(toneName or "Accent")
    fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
    Components.corner(fill, 6)
    return track
end

-- ===== composites =====

-- A horizontal strip of tabs that scrolls when it does not fit. tabs = { { Id, Label } }.
function Components.tabStrip(parent, tabs, activeId, onSelect)
    local tap = Components.tapHeight()
    local strip = Instance.new("ScrollingFrame")
    strip.Name = "Tabs"
    strip.BackgroundTransparency = 1
    strip.BorderSizePixel = 0
    strip.ScrollBarThickness = 0
    strip.ScrollingDirection = Enum.ScrollingDirection.X
    strip.AutomaticCanvasSize = Enum.AutomaticSize.X
    strip.CanvasSize = UDim2.new()
    strip.Size = UDim2.new(1, 0, 0, tap)
    strip.Parent = parent
    Components.list(strip, Enum.FillDirection.Horizontal, 8)
    local buttons = {}
    for order, tab in tabs do
        local active = tab.Id == activeId
        local width = math.max(Components.measure(tab.Label, "Body").X + Components.textSize("Body") * 2.5, tap * 1.6)
        local button = Components.button(strip, {
            Name = "Tab_" .. tab.Id,
            Text = tab.Label,
            Width = math.ceil(width),
            Order = order,
            OnActivated = function()
                onSelect(tab.Id)
            end,
        })
        if active then
            button.BackgroundColor3 = Theme.Color.PanelSelected
            local underline = Components.frame(button, "ActiveMark")
            underline.BackgroundTransparency = 0
            underline.BackgroundColor3 = Theme.Color.Accent
            underline.AnchorPoint = Vector2.new(0.5, 1)
            underline.Position = UDim2.new(0.5, 0, 1, -4)
            underline.Size = UDim2.new(1, -20, 0, 4)
        end
        button:SetAttribute("Active", active)
        buttons[tab.Id] = button
    end
    return strip, buttons
end

-- One catalog item as a pressable card. props: Viewing (the card whose detail is shown),
-- OnActivated, Order. Selected (equipped) comes from the item itself.
function Components.card(parent, item, props)
    props = props or {}
    local access = CatalogItem.Access[item.Access] or CatalogItem.Access.Unavailable
    local accent = Components.tone(item.Accent)
    local size = Components.cardSize()
    local card = Instance.new("TextButton")
    card.Name = "Card_" .. item.Id
    card.AutoButtonColor = false
    card.BorderSizePixel = 0
    card.Text = ""
    card.Size = UDim2.fromOffset(size.X, size.Y)
    card.BackgroundColor3 = props.Viewing and Theme.Color.PanelSelected or Theme.Color.PanelHigh
    card.LayoutOrder = props.Order or 0
    card.Parent = parent
    Components.corner(card, 12)
    -- Equipped: thicker outline and a tag. Viewing: a lighter surface and a side bar.
    Components.stroke(card, item.Selected and accent or Theme.Color.PanelSelected, item.Selected and 3 or 1)
    if props.Viewing then
        local bar = Components.frame(card, "ViewingMark")
        bar.BackgroundTransparency = 0
        bar.BackgroundColor3 = Theme.Color.Text
        bar.Position = UDim2.fromOffset(0, 12)
        bar.Size = UDim2.new(0, 4, 1, -24)
    end

    local body = Components.frame(card, "Body")
    body.Size = UDim2.fromScale(1, 1)
    Components.pad(body, 12)
    Components.list(body, Enum.FillDirection.Vertical, 4)
    Components.label(body, item.Title, "Body", {
        Name = "Title",
        Color = access.Usable and accent or Theme.Color.Text,
        Font = Enum.Font.GothamBlack,
        Lines = 2,
        Order = 1,
    })
    Components.label(body, item.Subtitle, "Label", {
        Name = "Subtitle",
        Color = Theme.Color.TextMuted,
        Font = Enum.Font.GothamMedium,
        Lines = 1,
        Order = 2,
    })
    local tags = Components.frame(body, "Tags")
    tags.LayoutOrder = 3
    tags.Size = UDim2.new(1, 0, 0, Components.line("Label") + 6)
    Components.list(tags, Enum.FillDirection.Horizontal, 6)
    local accessBadge = Components.badge(tags, access.Label, access.Tone, false)
    accessBadge.Name = "Access"
    if item.Selected then
        local equipped = Components.badge(tags, props.SelectedLabel or "EQUIPPED", item.Accent or "Accent", true)
        equipped.Name = "Selected"
    end
    card:SetAttribute("ItemId", item.Id)
    if props.OnActivated then
        card.Activated:Connect(props.OnActivated)
    end
    return card
end

-- A scrolling container for cards: "Row" scrolls sideways, "Grid" wraps and scrolls down.
function Components.cardList(parent, mode)
    local size = Components.cardSize()
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Cards"
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Theme.Color.TextMuted
    scroll.CanvasSize = UDim2.new()
    scroll.Parent = parent
    if mode == "Row" then
        scroll.ScrollingDirection = Enum.ScrollingDirection.X
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
        Components.list(scroll, Enum.FillDirection.Horizontal, Components.GAP)
    else
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.fromOffset(size.X, size.Y)
        grid.CellPadding = UDim2.fromOffset(Components.GAP, Components.GAP)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = scroll
    end
    -- room for the 3 px equipped outline, which a scrolling frame would otherwise clip
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 3)
    padding.PaddingTop = UDim.new(0, 3)
    padding.PaddingRight = UDim.new(0, 3)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.Parent = scroll
    return scroll
end

-- Everything the player needs to decide on one item: name, role, access, what it does, and the
-- one line about time or price. `compact` leaves the section bodies out (pre-match lock-in).
function Components.detail(parent, item, compact)
    local access = CatalogItem.Access[item.Access] or CatalogItem.Access.Unavailable
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Detail"
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Theme.Color.TextMuted
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.Parent = parent
    Components.list(scroll, Enum.FillDirection.Vertical, 6)
    local padding = Instance.new("UIPadding")
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = scroll

    Components.label(scroll, item.Title, compact and "Body" or "Title", {
        Name = "Title",
        Color = Components.tone(item.Accent),
        Font = Enum.Font.GothamBlack,
        Order = 1,
    })
    Components.label(scroll, item.Subtitle:upper() .. "  ·  " .. access.Label, "Label", {
        Name = "Role",
        Color = Theme.Color.TextMuted,
        Order = 2,
    })
    Components.label(scroll, item.Summary, "Body", { Name = "Summary", Font = Enum.Font.GothamMedium, Order = 3 })
    local order = 4
    for _, section in item.Sections or {} do
        Components.label(
            scroll,
            section.Heading,
            "Label",
            { Name = "Heading", Color = Theme.Color.Accent, Order = order }
        )
        if not compact then
            Components.label(scroll, section.Body, "Body", {
                Name = "SectionBody",
                Font = Enum.Font.GothamMedium,
                Order = order + 1,
            })
        end
        order += 2
    end
    local line = Components.accessLine(item, Components.now())
    if line ~= "" then
        local accessLabel = Components.label(scroll, line, "Label", {
            Name = "AccessLine",
            Color = Components.tone(access.Tone),
            Order = order,
        })
        if item.Access == "Trial" and item.EndsAt then
            Components.countdown(accessLabel, item.EndsAt, function(left)
                return left > 0 and ("FREE FOR " .. Components.duration(left)) or "TRIAL ENDED"
            end)
        end
    end
    return scroll
end

-- Keep a label showing the time left until `endsAt` (server time). The server decides what
-- happens at zero; this only displays it. Stops by itself when the label is destroyed.
function Components.countdown(label, endsAt, format)
    local function update()
        label.Text = format(math.max(0, endsAt - Components.now()))
    end
    update()
    task.spawn(function()
        while label.Parent do
            task.wait(0.2)
            if label.Parent then
                update()
            end
        end
    end)
end

-- Keep a label showing the time since `since` (server time), for a queue timer.
function Components.elapsed(label, since, format)
    local function update()
        label.Text = format(math.max(0, Components.now() - since))
    end
    update()
    task.spawn(function()
        while label.Parent do
            task.wait(0.5)
            if label.Parent then
                update()
            end
        end
    end)
end

-- A count on the corner of a button: something there is unclaimed or new. It is a number, so
-- it does not rely on colour. Nothing is drawn for zero.
function Components.dot(button, count)
    if not count or count <= 0 then
        return nil
    end
    local height = Components.line("Label") + 4
    local ui = Instance.new("TextLabel")
    ui.Name = "Dot"
    ui.BorderSizePixel = 0
    ui.Text = count > 9 and "9+" or tostring(count)
    ui.Font = Enum.Font.GothamBlack
    ui.TextSize = Components.textSize("Label")
    ui.AnchorPoint = Vector2.new(1, 0)
    ui.Position = UDim2.new(1, -4, 0, 4)
    ui.Size = UDim2.fromOffset(math.max(height, Components.measure(ui.Text, "Label").X + 10), height)
    ui.BackgroundColor3 = Theme.Color.Danger
    ui.TextColor3 = Theme.Color.Panel
    ui.ZIndex = button.ZIndex + 1
    Components.corner(ui, math.floor(height / 2))
    ui.Parent = button
    button:SetAttribute("Dot", count)
    return ui
end

-- What a screen shows in place of its content while it has none. One look for all four, so a
-- player learns it once. props: Text (replaces the default line), OnRetry (Error and Offline).
Components.States = {
    Loading = { Title = "LOADING", Text = "One moment.", Tone = "TextMuted" },
    Empty = { Title = "NOTHING HERE YET", Text = "Check back later.", Tone = "TextMuted" },
    Error = { Title = "SOMETHING WENT WRONG", Text = "Nothing was changed.", Tone = "Danger", Retry = true },
    Offline = { Title = "CONNECTION LOST", Text = "Waiting for the server.", Tone = "Warn", Retry = true },
}

function Components.state(parent, kind, props)
    props = props or {}
    local spec = Components.States[kind] or Components.States.Error
    local block = Components.frame(parent, "State")
    block:SetAttribute("Kind", kind)
    local layout = Components.list(block, Enum.FillDirection.Vertical, Components.GAP)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    Components.label(block, spec.Title, "Title", {
        Name = "StateTitle",
        Color = Components.tone(spec.Tone),
        Font = Enum.Font.GothamBlack,
        Align = Enum.TextXAlignment.Center,
        Order = 1,
    })
    Components.label(block, props.Text or spec.Text, "Body", {
        Name = "StateText",
        Color = Theme.Color.TextMuted,
        Font = Enum.Font.GothamMedium,
        Align = Enum.TextXAlignment.Center,
        Order = 2,
    })
    local retry
    if spec.Retry and props.OnRetry then
        retry = Components.button(block, {
            Name = "Retry",
            Text = "TRY AGAIN",
            Width = Components.measure("TRY AGAIN", "Body").X + 56,
            Order = 3,
            OnActivated = props.OnRetry,
        })
    end
    return block, retry
end

-- tone: a Theme.Color name. Errors carry a text prefix as well as a colour.
function Components.statusLine(parent, text, toneName)
    local shown = text or ""
    if toneName == "Danger" and shown ~= "" then
        shown = "!  " .. shown
    end
    return Components.label(parent, shown, "Label", {
        Name = "Status",
        Color = Components.tone(toneName or "TextMuted"),
        Font = Enum.Font.GothamMedium,
        Lines = 1,
    })
end

-- The primary action for an item, from its Action. onAction(actionName) fires only for
-- enabled actions; a disabled one is a readout.
function Components.actionButton(parent, item, onAction)
    local action = CatalogItem.Actions[item.Action] or CatalogItem.Actions.Unavailable
    local text = action.Label
    if item.Action == "Buy" and item.Price then
        text = "BUY  ·  " .. Components.price(item.Price)
    end
    local button = Components.button(parent, {
        Name = "PrimaryAction",
        Text = text,
        Style = "Primary",
        Enabled = action.Enabled,
        OnActivated = function()
            onAction(item.Action)
        end,
    })
    button.Visible = item.Action ~= "None"
    button:SetAttribute("Action", item.Action)
    return button
end

-- A confirmation laid over `parent` (the modal panel). props: Title, Body, ConfirmText,
-- OnConfirm, OnCancel. Returns the overlay and its confirm / cancel buttons.
function Components.confirm(parent, props)
    local overlay = Instance.new("TextButton") -- a button so it swallows presses on what is behind it
    overlay.Name = "Confirm"
    overlay.AutoButtonColor = false
    overlay.Selectable = false
    overlay.Text = ""
    overlay.BorderSizePixel = 0
    overlay.BackgroundColor3 = Theme.Color.Panel
    overlay.BackgroundTransparency = Components.surface(Theme.Transparency.Panel)
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = 10
    overlay.Parent = parent
    Components.corner(overlay, 16)

    local box = Components.panel(overlay, "Box", Theme.Color.PanelRaised)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.new(0.6, 0, 0, 0)
    box.AutomaticSize = Enum.AutomaticSize.Y
    box.ZIndex = 11
    Components.stroke(box, Theme.Color.Accent, 2)
    Components.pad(box, Components.PAD)
    Components.list(box, Enum.FillDirection.Vertical, Components.GAP)
    Components.label(box, props.Title, "Title", { Name = "Title", Color = Theme.Color.Accent, Order = 1 }).ZIndex = 12
    Components.label(box, props.Body, "Body", { Name = "Body", Font = Enum.Font.GothamMedium, Order = 2 }).ZIndex = 12

    local buttons = Components.frame(box, "Buttons")
    buttons.LayoutOrder = 3
    buttons.Size = UDim2.new(1, 0, 0, Components.tapHeight())
    buttons.ZIndex = 12
    local function close()
        overlay:Destroy()
    end
    local cancel = Components.button(buttons, {
        Name = "Cancel",
        Text = "CANCEL",
        OnActivated = function()
            close()
            if props.OnCancel then
                props.OnCancel()
            end
        end,
    })
    cancel.Size = UDim2.new(0.5, -5, 1, 0)
    cancel.ZIndex = 13
    local confirm = Components.button(buttons, {
        Name = "ConfirmAction",
        Text = props.ConfirmText or "CONFIRM",
        Style = "Primary",
        OnActivated = function()
            close()
            props.OnConfirm()
        end,
    })
    confirm.AnchorPoint = Vector2.new(1, 0)
    confirm.Position = UDim2.fromScale(1, 0)
    confirm.Size = UDim2.new(0.5, -5, 1, 0)
    confirm.ZIndex = 13
    return overlay, confirm, cancel
end

return Components
