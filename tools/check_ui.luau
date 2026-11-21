-- Build gate: catalog-style UI (kits, packs, passes) is data drawn by shared components.
--
--   * records: CatalogItem.validate accepts the mock catalog and refuses contradictory records
--   * the three CatalogScreen templates are built here, without Studio, against the real
--     Screen and Theme maths for a phone, a Split View tablet, a tablet, a desktop and a
--     console. Every property the code sets is checked against the Roblox API, and for each
--     build: no region falls outside the panel or overlaps another, everything pressable is at
--     least 44pt, no text is under the device's floor, every card states its access in words
--   * behaviour: a purchase needs a confirmation, a disabled action cannot be pressed, the
--     lock-in never offers a purchase and switches off at its deadline
--   * one way to build widgets: a controller may not add a raw ScreenGui, button, label,
--     scrolling frame or Color3.fromRGB beyond what it already had (tools/ui_baseline.json;
--     the numbers may only go down, and a new controller starts at zero)
--
-- What it cannot check is how it looks: spacing, wrapping, the 3D preview, real fonts. That
-- needs the gallery in Studio (Tuning.Debug_UiGallery) under the device emulator.
--
--     lune run tools/check_ui.luau
--     lune run tools/check_ui.luau --update-baseline     after removing raw widgets
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

Color3 = roblox.Color3
Enum = roblox.Enum
UDim = roblox.UDim
UDim2 = roblox.UDim2
Vector2 = roblox.Vector2

local passed, failed = 0, 0
local function check(what, cond, detail)
    if cond then
        passed += 1
        print("PASS  " .. what)
    else
        failed += 1
        print("FAIL  " .. what .. (detail and ("\n        " .. tostring(detail)) or ""))
    end
end

-- ===== 1. records =====
local CatalogItem = require("../src/shared/CatalogItem")

local function loadPlain(path, env)
    return luau.load(fs.readFile(path), { debugName = path, injectGlobals = true, environment = env or {} })()
end

local MockCatalog = loadPlain("src/client/UI/MockCatalog.lua")
local NOW = 1790000000
local mockItems = MockCatalog.items(NOW)
local problems = CatalogItem.validateAll(mockItems)
check("mock catalog records are valid", #problems == 0, table.concat(problems, "\n        "))
problems = CatalogItem.validateAll(MockCatalog.lockIn(NOW))
check("mock lock-in records are valid", #problems == 0, table.concat(problems, "\n        "))
problems = CatalogItem.validateTrack(MockCatalog.track(NOW))
check("mock season track is valid", #problems == 0, table.concat(problems, "\n        "))

local seenAccess, seenAction = {}, {}
for _, item in mockItems do
    seenAccess[item.Access] = true
    seenAction[item.Action] = true
end
for _, item in MockCatalog.lockIn(NOW) do
    seenAction[item.Action] = true
end
local missing = {}
for name in CatalogItem.Access do
    if not seenAccess[name] then
        table.insert(missing, "access " .. name)
    end
end
for name in CatalogItem.Actions do
    if not seenAction[name] and name ~= "Claim" and name ~= "MatchLocked" then
        table.insert(missing, "action " .. name)
    end
end
check("the gallery shows every access label and action", #missing == 0, table.concat(missing, ", "))

local function base()
    return {
        Id = "X",
        Kind = "Kit",
        Title = "X",
        Subtitle = "Role",
        Summary = "Does a thing.",
        Access = "Owned",
        Selected = false,
        Action = "Equip",
    }
end
local function refused(what, change)
    local item = base()
    change(item)
    check("refused: " .. what, #CatalogItem.validate(item) > 0)
end
check("a plain record is accepted", #CatalogItem.validate(base()) == 0)
refused("equipped while locked", function(item)
    item.Access, item.Selected, item.Action = "Locked", true, "Equipped"
end)
refused("equip offered on a locked item", function(item)
    item.Access = "Locked"
end)
refused("buy without a price", function(item)
    item.Access, item.Action = "Locked", "Buy"
end)
refused("buy offered on an owned item", function(item)
    item.Action, item.Price = "Buy", { Amount = 100, Currency = "Credits" }
end)
refused("a trial with no end time", function(item)
    item.Access = "Trial"
end)
refused("a title over the limit", function(item)
    item.Title = string.rep("W", CatalogItem.Limits.Title + 1)
end)
refused("five detail sections", function(item)
    item.Sections = table.create(5, { Heading = "H", Body = "B" })
end)
refused("an unknown accent colour", function(item)
    item.Accent = "Purple"
end)
refused("'equipped' action on an unselected item", function(item)
    item.Action = "Equipped"
end)

local themeSource = fs.readFile("src/client/UI/Theme.lua")
local unknownAccent = {}
for _, accent in CatalogItem.Accents do
    if not themeSource:find("\n    " .. accent .. " = Color3", 1, true) then
        table.insert(unknownAccent, accent)
    end
end
for _, spec in CatalogItem.Access do
    if not table.find(CatalogItem.Accents, spec.Tone) then
        table.insert(unknownAccent, spec.Tone)
    end
end
check("every accent a record may name is a Theme.Color token", #unknownAccent == 0, table.concat(unknownAccent, ", "))

-- ===== 2. offline build =====
-- Instances are real (Lune's copy of the Roblox API), so a misspelt property or a wrong type
-- fails here. The tree and the events are kept by this wrapper, because Lune has no events.
local STOP = "check_ui: stopped a background loop"
local EVENTS = { Activated = true, MouseButton1Click = true, SelectionGained = true }
local wrapperMeta = {}

local function signal()
    local handlers = {}
    return {
        handlers = handlers,
        Connect = function(_, fn)
            table.insert(handlers, fn)
            return { Disconnect = function() end }
        end,
    }
end

local methods = {}
function methods:GetChildren()
    return table.clone(self._children)
end
function methods:GetDescendants()
    local out = {}
    local function walk(node)
        for _, child in node._children do
            table.insert(out, child)
            walk(child)
        end
    end
    walk(self)
    return out
end
function methods:IsA(class)
    return self._real:IsA(class)
end
function methods:FindFirstChildOfClass(class)
    for _, child in self._children do
        if child._real.ClassName == class then
            return child
        end
    end
    return nil
end
function methods:FindFirstChild(name)
    for _, child in self._children do
        if child._real.Name == name then
            return child
        end
    end
    return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods:Destroy()
    self.Parent = nil
    self._destroyed = true
end
function methods:SetAttribute(name, value)
    self._attributes[name] = value
end
function methods:GetAttribute(name)
    return self._attributes[name]
end
function methods:GetPropertyChangedSignal()
    return signal()
end
function methods:GetFullName()
    return self._real.Name
end

wrapperMeta.__index = function(self, key)
    if key == "Parent" then
        return rawget(self, "_parent")
    elseif methods[key] then
        return methods[key]
    elseif EVENTS[key] then
        local signals = rawget(self, "_signals")
        signals[key] = signals[key] or signal()
        return signals[key]
    end
    return rawget(self, "_real")[key]
end
wrapperMeta.__newindex = function(self, key, value)
    if key == "Parent" then
        local old = rawget(self, "_parent")
        if old then
            table.remove(old._children, table.find(old._children, self))
        end
        rawset(self, "_parent", value)
        if value then
            table.insert(value._children, self)
        end
    elseif key == "_destroyed" then
        rawset(self, key, value)
    else
        rawget(self, "_real")[key] = value
    end
end

local function newInstance(class)
    return setmetatable({
        _real = roblox.Instance.new(class),
        _children = {},
        _attributes = {},
        _signals = {},
    }, wrapperMeta)
end

local function fire(instance, event, ...)
    local signals = rawget(instance, "_signals")
    local fired = 0
    for _, handler in (signals[event] and signals[event].handlers or {}) do
        handler(...)
        fired += 1
    end
    return fired
end

local function find(root, name)
    for _, node in root:GetDescendants() do
        if node.Name == name then
            return node
        end
    end
    return nil
end

local DEVICES = {
    { Name = "phone 812x375", Viewport = Vector2.new(812, 375), Touch = true, Inset = 36 },
    { Name = "small phone 667x375", Viewport = Vector2.new(667, 375), Touch = true, Inset = 36 },
    { Name = "tablet Split View 507x768", Viewport = Vector2.new(507, 768), Touch = true, Inset = 36 },
    { Name = "tablet 1180x820", Viewport = Vector2.new(1180, 820), Touch = true, Inset = 36 },
    { Name = "desktop 1920x1080", Viewport = Vector2.new(1920, 1080), Touch = false, Inset = 36 },
    { Name = "small window 1024x600", Viewport = Vector2.new(1024, 600), Touch = false, Inset = 36 },
    { Name = "console 1920x1080", Viewport = Vector2.new(1920, 1080), Touch = false, Console = true, Inset = 36 },
}
-- The same screens with the player's accessibility settings on. 1.3 is an assumed text growth.
local ACCESS_DEVICES = {
    {
        Name = "phone 812x375, larger text",
        Viewport = Vector2.new(812, 375),
        Touch = true,
        Inset = 36,
        TextGrowth = 1.3,
        Transparency = 0,
    },
    {
        Name = "tablet Split View 507x768, larger text",
        Viewport = Vector2.new(507, 768),
        Touch = true,
        Inset = 36,
        TextGrowth = 1.3,
    },
    {
        Name = "desktop 1920x1080, larger text",
        Viewport = Vector2.new(1920, 1080),
        Touch = false,
        Inset = 36,
        TextGrowth = 1.3,
        Transparency = 0,
        ReducedMotion = true,
    },
}
local ALL_DEVICES = table.clone(DEVICES)
for _, device in ACCESS_DEVICES do
    table.insert(ALL_DEVICES, device)
end

-- A fresh copy of Screen, Theme, Components and CatalogScreen for one device.
local function world(device)
    local playerGui = newInstance("Folder")
    local delayed = {}
    local clock = { now = NOW }
    local input = { Gamepad = false }
    local guiService = {
        SelectedObject = nil,
        PreferredTransparency = device.Transparency,
        ReducedMotionEnabled = device.ReducedMotion,
        IsTenFootInterface = function()
            return device.Console == true
        end,
        GetGuiInset = function()
            return Vector2.new(0, device.Inset), Vector2.new(0, 0)
        end,
        GetPropertyChangedSignal = function()
            return signal()
        end,
    }
    local services = {
        GuiService = guiService,
        UserInputService = {
            TouchEnabled = device.Touch,
            KeyboardEnabled = not device.Touch,
            MouseEnabled = not device.Touch,
            GetLastInputType = function()
                return input.Gamepad and Enum.UserInputType.Gamepad1 or Enum.UserInputType.MouseButton1
            end,
            GetPropertyChangedSignal = function()
                return signal()
            end,
        },
        Workspace = {
            CurrentCamera = {
                ViewportSize = device.Viewport,
                GetPropertyChangedSignal = function()
                    return signal()
                end,
            },
            GetPropertyChangedSignal = function()
                return signal()
            end,
            GetServerTimeNow = function()
                return clock.now
            end,
        },
        Players = {
            LocalPlayer = {
                Character = nil,
                WaitForChild = function()
                    return playerGui
                end,
            },
        },
        ReplicatedStorage = { Shared = { CatalogItem = "CatalogItem", Palette = "Palette" } },
        StarterGui = { SetCoreGuiEnabled = function() end },
        -- The engine draws text larger under the player's Text Size setting and TextService
        -- reports the larger size. The real multipliers are not documented; TextGrowth is an
        -- assumed one, so these builds prove the layout follows measured text, not a number.
        TextService = {
            GetTextSize = function(_, text, size)
                local growth = device.TextGrowth or 1
                return Vector2.new(math.ceil(#text * size * 0.6 * growth), math.ceil(size * 1.2) * growth)
            end,
        },
        RunService = { BindToRenderStep = function() end, UnbindFromRenderStep = function() end },
        ContextActionService = { BindAction = function() end, UnbindAction = function() end },
    }
    local modules = { CatalogItem = CatalogItem }
    local env
    local function load(name, path)
        modules[name] = luau.load(fs.readFile(path), { debugName = path, injectGlobals = true, environment = env })()
        return modules[name]
    end
    env = {
        game = {
            GetService = function(_, name)
                return assert(services[name], "check_ui has no fake for service " .. name)
            end,
        },
        script = {
            Parent = {
                Screen = "Screen",
                Theme = "Theme",
                Components = "Components",
                ScreenStack = "ScreenStack",
                LobbyShell = "LobbyShell",
            },
        },
        require = function(key)
            return assert(modules[key], "check_ui cannot require " .. tostring(key))
        end,
        Instance = { new = newInstance },
        Enum = roblox.Enum,
        Color3 = roblox.Color3,
        UDim = roblox.UDim,
        UDim2 = roblox.UDim2,
        Vector2 = roblox.Vector2,
        warn = function(...)
            error("unexpected warn: " .. table.concat({ ... }, " "))
        end,
        task = {
            -- run it now; a loop that waits is stopped at its first wait
            spawn = function(fn, ...)
                local ok, err = pcall(fn, ...)
                if not ok and not tostring(err):find(STOP, 1, true) then
                    error(err, 0)
                end
            end,
            wait = function()
                error(STOP, 0)
            end,
            delay = function(_, fn)
                table.insert(delayed, fn)
            end,
        },
    }
    load("Palette", "src/shared/Palette.lua")
    local Screen = load("Screen", "src/client/UI/Screen.lua")
    Screen.start()
    load("Theme", "src/client/UI/Theme.lua")
    load("Components", "src/client/UI/Components.lua")
    load("CatalogScreen", "src/client/UI/CatalogScreen.lua")
    load("ScreenStack", "src/client/UI/ScreenStack.lua")
    load("LobbyShell", "src/client/UI/LobbyShell.lua")
    return {
        ScreenStack = modules.ScreenStack,
        LobbyShell = modules.LobbyShell,
        PlayerGui = playerGui,
        Input = input,
        Screen = Screen,
        Theme = modules.Theme,
        Components = modules.Components,
        CatalogScreen = modules.CatalogScreen,
        GuiService = guiService,
        Delayed = delayed,
        Clock = clock,
    }
end

-- Layout rules for one built screen. Returns a list of problems.
local function audit(w, screen)
    local issues = {}
    local state = w.Screen.get()
    local panel = screen.Panel
    local width, height = panel.Size.X.Offset, panel.Size.Y.Offset
    local tap = w.Components.tapHeight()
    local floor = math.floor(w.Theme.textSize(1) + 0.5)

    -- the panel fits the screen once scaled
    if
        width * state.Scale > state.Viewport.X + 0.5
        or height * state.Scale > state.Viewport.Y - state.Insets.Top + 0.5
    then
        table.insert(issues, ("panel %dx%d at scale %.2f is larger than the screen"):format(width, height, state.Scale))
    end

    -- regions: inside the panel, not negative, not overlapping
    local body = panel:FindFirstChild("Body")
    local rects = {}
    for _, child in body:GetChildren() do
        if child:IsA("GuiObject") and child.Name ~= "Confirm" and child.Visible then
            local x, y = child.Position.X.Offset, child.Position.Y.Offset
            local sx, sy = child.Size.X.Offset, child.Size.Y.Offset
            if sx < 0 or sy < 0 then
                table.insert(issues, ("%s has a negative size (%d x %d)"):format(child.Name, sx, sy))
            elseif sx > 0 and sy > 0 then
                if x < 0 or y < 0 or x + sx > width + 0.5 or y + sy > height + 0.5 then
                    table.insert(
                        issues,
                        ("%s leaves the panel (%d,%d %dx%d in %dx%d)"):format(child.Name, x, y, sx, sy, width, height)
                    )
                end
                table.insert(rects, { child.Name, x, y, x + sx, y + sy })
            end
            if (child.Name == "Detail" or child.Name == "Cards") and sy < tap then
                table.insert(issues, ("%s is only %d tall"):format(child.Name, sy))
            end
        end
    end
    for i = 1, #rects do
        for j = i + 1, #rects do
            local a, b = rects[i], rects[j]
            if a[2] < b[4] and a[4] > b[2] and a[3] < b[5] and a[5] > b[3] then
                table.insert(issues, ("%s overlaps %s"):format(a[1], b[1]))
            end
        end
    end

    for _, node in panel:GetDescendants() do
        if node:IsA("TextButton") and node.Name ~= "Confirm" then
            -- a height given in scale is inside a row that is itself checked
            if node.Size.Y.Scale == 0 and node.Size.Y.Offset < tap then
                table.insert(
                    issues,
                    ("%s is %d tall, the tap minimum here is %d"):format(node.Name, node.Size.Y.Offset, tap)
                )
            end
            if node:GetAttribute("Enabled") == false and (node.Selectable or node.Active) then
                table.insert(issues, node.Name .. " is disabled but can still take focus")
            end
        end
        if (node:IsA("TextButton") or node:IsA("TextLabel")) and node.Text ~= "" and node.TextSize < floor then
            table.insert(issues, ("%s text is %d, the floor here is %d"):format(node.Name, node.TextSize, floor))
        end
        if node.Name:sub(1, 5) == "Card_" then
            local access = find(node, "Access")
            if not access or access.Text == "" then
                table.insert(issues, node.Name .. " has no access label")
            end
        end
    end
    return issues
end

local function build(device, template)
    local w = world(device)
    local actions = {}
    local screen = w.CatalogScreen.new({
        Name = "Check" .. template,
        Template = template,
        Title = "CHECK",
        Tabs = MockCatalog.Tabs,
        ConfirmNote = "Kits are sidegrades, not upgrades.",
        Preview = function()
            return false
        end,
        OnAction = function(item, action)
            table.insert(actions, { item, action })
        end,
    })
    if template == "Browser" then
        screen:SetItems(MockCatalog.items(NOW))
    elseif template == "LockIn" then
        screen:SetItems(MockCatalog.lockIn(NOW))
        screen:SetDeadline(NOW + 10, "Penthouse")
    else
        screen:SetTrack(MockCatalog.track(NOW))
    end
    screen:Open()
    return w, screen, actions
end

for _, device in ALL_DEVICES do
    for _, template in { "Browser", "LockIn", "Track" } do
        local ok, w, screen = pcall(build, device, template)
        if not ok then
            check(("%s builds on %s"):format(template, device.Name), false, w)
        else
            local issues = audit(w, screen)
            if template == "Browser" then
                -- every tab and every card, so each record is drawn in the detail panel too
                for _, tab in MockCatalog.Tabs do
                    screen.Tab = tab.Id
                    for _, item in screen:Visible() do
                        screen.ViewingId = item.Id
                        local drawn, err = pcall(screen.Render, screen)
                        if not drawn then
                            table.insert(issues, ("%s / %s: %s"):format(tab.Id, item.Id, tostring(err)))
                        else
                            for _, issue in audit(w, screen) do
                                table.insert(issues, ("%s / %s: %s"):format(tab.Id, item.Id, issue))
                            end
                        end
                    end
                end
            end
            -- the four shared states, in place of the content
            for kind in w.Components.States do
                local drawn, err = pcall(screen.SetLoad, screen, kind)
                if not drawn then
                    table.insert(issues, ("state %s: %s"):format(kind, tostring(err)))
                else
                    local block = find(screen.Panel, "State")
                    if not block or block:GetAttribute("Kind") ~= kind then
                        table.insert(issues, ("state %s was not drawn"):format(kind))
                    end
                    if find(screen.Panel, "PrimaryAction") or find(screen.Panel, "Cards") then
                        table.insert(issues, ("state %s still shows content"):format(kind))
                    end
                    for _, issue in audit(w, screen) do
                        table.insert(issues, ("state %s: %s"):format(kind, issue))
                    end
                end
            end
            screen:SetLoad(nil)
            if device.Transparency == 0 and screen.Panel.BackgroundTransparency ~= 0 then
                table.insert(issues, "the panel is not opaque although the player asked for opaque backgrounds")
            end
            check(
                ("%s on %s (%s, scale %.2f)"):format(template, device.Name, w.Screen.get().Class, w.Screen.get().Scale),
                #issues == 0,
                table.concat(issues, "\n        ")
            )
        end
    end
end

-- ===== 3. behaviour =====
do
    local w, screen, actions = build(DEVICES[5], "Browser")
    local card = find(screen.Panel, "Card_Accretor")
    check("pressing a card shows it without acting", card ~= nil and fire(card, "Activated") == 1 and #actions == 0)
    local action = find(screen.Panel, "PrimaryAction")
    check(
        "a locked item offers BUY with its price",
        action ~= nil and action.Text:find("4,500 CREDITS", 1, true) ~= nil,
        action and action.Text
    )
    fire(action, "Activated")
    local confirm = find(screen.Panel, "ConfirmAction")
    check("BUY opens a confirmation and buys nothing yet", confirm ~= nil and #actions == 0)
    local text = find(find(screen.Panel, "Confirm"), "Body").Text
    check(
        "the confirmation states price, permanence and the sidegrade note",
        text:find("4,500 CREDITS", 1, true) and text:find("permanent", 1, true) and text:find("sidegrades", 1, true),
        text
    )
    fire(confirm, "Activated")
    check(
        "confirming sends one Buy request",
        #actions == 1 and actions[1][2] == "Buy" and actions[1][1].Id == "Accretor"
    )
    check(
        "the screen did not mark it owned by itself",
        find(find(screen.Panel, "Card_Accretor"), "Access").Text == "LOCKED"
    )

    screen.ViewingId = "Neutron"
    screen:Render()
    action = find(screen.Panel, "PrimaryAction")
    check(
        "the equipped item shows EQUIPPED and cannot be pressed",
        action.Text == "EQUIPPED" and fire(action, "Activated") == 0 and not action.Selectable
    )
    check(
        "the equipped card carries a tag, not only a colour",
        find(find(screen.Panel, "Card_Neutron"), "Selected") ~= nil
    )

    screen.ViewingId = "Neutrino"
    screen:Render()
    fire(find(screen.Panel, "PrimaryAction"), "Activated")
    check(
        "EQUIP sends a request and waits for the server",
        #actions == 2 and actions[2][2] == "Equip" and find(find(screen.Panel, "Card_Neutrino"), "Selected") == nil
    )

    local okBad, err = pcall(
        screen.SetItems,
        screen,
        { { Id = "Bad", Kind = "Kit", Title = "BAD", Access = "Owned", Action = "Buy" } }
    )
    check(
        "a contradictory record is refused with a warning, not drawn",
        not okBad and tostring(err):find("left out", 1, true) ~= nil,
        err
    )

    screen.Filter = "Owned"
    local owned = {}
    for _, item in screen:Visible() do
        table.insert(owned, item.Access)
    end
    screen:SetItems(MockCatalog.items(NOW))
    screen.Tab, screen.Filter = "Kit", "Owned"
    owned = {}
    for _, item in screen:Visible() do
        if item.Access ~= "Owned" and item.Access ~= "Starter" then
            table.insert(owned, item.Id)
        end
    end
    check("the OWNED filter leaves out trials and locked items", #owned == 0, table.concat(owned, ", "))
    w.GuiService.SelectedObject = find(screen.Panel, "Close")
    screen.Focus = "action"
    screen:Render()
    check(
        "controller focus survives a redraw",
        w.GuiService.SelectedObject ~= nil and w.GuiService.SelectedObject.Name ~= "Close"
    )
end

do
    local w, screen, actions = build(DEVICES[1], "LockIn")
    local offers = {}
    for _, node in screen.Panel:GetDescendants() do
        if node.Name:sub(1, 5) == "Card_" then
            local id = node:GetAttribute("ItemId")
            for _, item in MockCatalog.lockIn(NOW) do
                if item.Id == id and (item.Action == "Buy" or not CatalogItem.Access[item.Access].Usable) then
                    table.insert(offers, id)
                end
            end
        end
    end
    check("the lock-in shows only usable kits and no purchase", #offers == 0, table.concat(offers, ", "))
    check("the saved kit is already locked in", find(screen.Panel, "PrimaryAction").Text == "LOCKED IN")
    check("the lock-in has no close button", find(screen.Panel, "Close") == nil)
    check(
        "the countdown reads the server deadline",
        find(screen.Panel, "Countdown").Text == "DEPLOYING IN 10.0",
        find(screen.Panel, "Countdown").Text
    )
    fire(find(screen.Panel, "Card_Neutrino"), "Activated")
    fire(find(screen.Panel, "PrimaryAction"), "Activated")
    check("SELECT sends a request", #actions == 1 and actions[1][2] == "Select")
    w.Clock.now = NOW + 11
    for _, fn in w.Delayed do
        fn()
    end
    local action = find(screen.Panel, "PrimaryAction")
    check(
        "at the deadline the action reads MATCH LOCKED and cannot be pressed",
        action.Text == "MATCH LOCKED" and fire(action, "Activated") == 0,
        action.Text
    )
end

do
    local _, screen, actions = build(DEVICES[5], "Track")
    local claimable, pressed = 0, 0
    for _, node in screen.Panel:GetDescendants() do
        if node.Name == "FreeReward" or node.Name == "PremiumReward" then
            local n = fire(node, "Activated")
            pressed += n
            if node:GetAttribute("Enabled") then
                claimable += 1
            end
        end
    end
    check(
        "only claimable rewards can be pressed",
        claimable == 1 and pressed == 1 and #actions == 1 and actions[1][2] == "Claim"
    )
    local action = find(screen.Panel, "PrimaryAction")
    check("premium is offered with its price", action.Text:find("799 ROBUX", 1, true) ~= nil, action.Text)
    fire(action, "Activated")
    check("buying premium asks for confirmation first", find(screen.Panel, "ConfirmAction") ~= nil and #actions == 1)
end

-- ===== 4. lobby shell =====
-- The shell is not a panel: its pieces sit along the screen edges. Each piece must stay on
-- screen, clear of the other pieces, the thumb zones and the hotbar, and keep its text whole.
local function auditShell(w, shell)
    local issues = {}
    local state = w.Screen.get()
    local width, height = shell.Layout.Width, shell.Layout.Height
    local scale = state.Scale
    local tap = w.Components.tapHeight()
    local floor = math.floor(w.Theme.textSize(1) + 0.5)
    local top, left, right = state.Insets.Top / scale, state.Insets.Left / scale, state.Insets.Right / scale
    local hotbar = { 0.25, 1 - (state.Insets.Bottom + 100) / state.Viewport.Y, 0.75, 1 }
    local rects = {}
    for _, panel in { shell.Main, shell.Top } do
        local body = panel:FindFirstChild("Body")
        for _, child in (body and body:GetChildren() or {}) do
            if child:IsA("GuiObject") then
                local x, y = child.Position.X.Offset, child.Position.Y.Offset
                local sx, sy = child.Size.X.Offset, child.Size.Y.Offset
                if sx <= 0 or sy <= 0 then
                    table.insert(issues, ("%s has no size (%d x %d)"):format(child.Name, sx, sy))
                else
                    if x < left - 0.5 or y < top - 0.5 or x + sx > width - right + 0.5 or y + sy > height + 0.5 then
                        table.insert(
                            issues,
                            ("%s leaves the safe area (%d,%d %dx%d in %dx%d)"):format(
                                child.Name,
                                x,
                                y,
                                sx,
                                sy,
                                width,
                                height
                            )
                        )
                    end
                    local zone = { x / width, y / height, (x + sx) / width, (y + sy) / height }
                    for _, reserved in
                        {
                            { "the left thumb zone", state.ThumbLeft },
                            { "the right thumb zone", state.ThumbRight },
                            { "the hotbar", hotbar },
                        }
                    do
                        if w.Screen.overlaps(zone, reserved[2]) then
                            table.insert(issues, ("%s is in %s"):format(child.Name, reserved[1]))
                        end
                    end
                    table.insert(rects, { child.Name, x, y, x + sx, y + sy })
                end
            end
        end
    end
    for i = 1, #rects do
        for j = i + 1, #rects do
            local a, b = rects[i], rects[j]
            if a[2] < b[4] and a[4] > b[2] and a[3] < b[5] and a[5] > b[3] then
                table.insert(issues, ("%s overlaps %s"):format(a[1], b[1]))
            end
        end
    end
    for _, panel in { shell.Main, shell.Top } do
        for _, node in panel:GetDescendants() do
            local isButton = node:IsA("TextButton")
            if isButton then
                if node.Size.Y.Offset < tap or node.Size.X.Offset < tap then
                    table.insert(
                        issues,
                        ("%s is %dx%d, the tap minimum here is %d"):format(
                            node.Name,
                            node.Size.X.Offset,
                            node.Size.Y.Offset,
                            tap
                        )
                    )
                end
                if node:GetAttribute("Enabled") == false and (node.Selectable or node.Active) then
                    table.insert(issues, node.Name .. " is disabled but can still take focus")
                end
            end
            if (isButton or node:IsA("TextLabel")) and node.Text ~= "" then
                if node.TextSize < floor then
                    table.insert(
                        issues,
                        ("%s text is %d, the floor here is %d"):format(node.Name, node.TextSize, floor)
                    )
                end
                -- text that does not fit is cut off, and here that loses the mode or the balance
                -- a label wraps onto as many whole lines as its box holds; a button has one line
                local needed = w.Components.measure(node.Text, "Body").X
                local lines = 1
                if not isButton and node.Size.Y.Scale == 0 then
                    lines = math.max(1, node.Size.Y.Offset // w.Components.line("Body"))
                end
                if node.Name ~= "Dot" and node.Size.X.Scale == 0 and node.Size.X.Offset * lines < needed then
                    table.insert(
                        issues,
                        ("%s is %d wide with room for %d line(s), its text needs %d"):format(
                            node.Name,
                            node.Size.X.Offset,
                            lines,
                            needed
                        )
                    )
                end
            end
        end
    end
    return issues
end

local function buildShell(device)
    local w = world(device)
    local mock = MockCatalog.shell(NOW)
    local events = {}
    local shell = w.LobbyShell.new({
        Name = "CheckShell",
        Destinations = mock.Destinations,
        OnNavigate = function(id, folded)
            table.insert(events, { "navigate", id, folded })
        end,
        OnLeaveQueue = function()
            table.insert(events, { "leave" })
        end,
        OnWallet = function()
            table.insert(events, { "wallet" })
        end,
    })
    shell:Show()
    return w, shell, mock, events
end

for _, device in ALL_DEVICES do
    local ok, w, shell, mock = pcall(buildShell, device)
    if not ok then
        check("Shell builds on " .. device.Name, false, w)
    else
        local issues = {}
        local function stage(name, fn)
            local drawn, err = pcall(fn)
            if not drawn then
                table.insert(issues, ("%s: %s"):format(name, tostring(err)))
                return
            end
            for _, issue in auditShell(w, shell) do
                table.insert(issues, ("%s: %s"):format(name, issue))
            end
        end
        stage("profile loading", function()
            local wallet = find(shell.Main, "Wallet")
            assert(wallet and wallet.Text == "LOADING..." and not wallet.Selectable, "the wallet should read LOADING")
        end)
        stage("everything on", function()
            shell:SetProfile(mock.Profile)
            shell:SetDots(mock.Dots)
            shell:SetQueue(mock.Queue)
            shell:Toast("Saved.", "Good")
            shell:Toast("Could not join: the queue is full.", "Danger")
            assert(find(shell.Top, "Queue") and find(shell.Top, "Toasts"), "queue strip and toasts should be drawn")
            assert(find(shell.Main, "Nav_Play"), "PLAY is always in the nav")
        end)
        stage("match found", function()
            shell:SetQueue({ State = "Found", Mode = mock.Queue.Mode })
            assert(find(shell.Top, "LeaveQueue") == nil, "a found match cannot be left from the strip")
        end)
        stage("a modal on top", function()
            shell:SetQueue(mock.Queue)
            local browser = w.CatalogScreen.new({
                Name = "CheckShellBrowser",
                Template = "Browser",
                Title = "CHECK",
                Tabs = MockCatalog.Tabs,
                Preview = function()
                    return false
                end,
            })
            browser:SetItems(MockCatalog.items(NOW))
            w.ScreenStack.push(browser)
            assert(not shell.MainGui.Enabled, "the nav hides under a modal")
            local strip = find(shell.Top, "Queue")
            assert(strip, "the queue strip stays above a modal")
            local state = w.Screen.get()
            local stripBottom = (strip.Position.Y.Offset + strip.Size.Y.Offset) * state.Scale
            local panelTop = state.Viewport.Y / 2
                + browser.Panel.Position.Y.Offset
                - browser.Panel.Size.Y.Offset * state.Scale / 2
            assert(
                panelTop >= stripBottom - 0.5,
                ("the modal starts at %d, under the queue strip that ends at %d"):format(panelTop, stripBottom)
            )
            for _, issue in audit(w, browser) do
                table.insert(issues, "modal under the queue strip: " .. issue)
            end
            w.ScreenStack.back()
            assert(shell.MainGui.Enabled and w.Components.Reserve.Top == 0, "closing the modal brings the nav back")
        end)
        stage("not queued", function()
            shell:SetQueue(nil)
            assert(find(shell.Top, "Queue") == nil, "no strip when not queued")
        end)
        check(
            ("Shell on %s (%s, scale %.2f)"):format(device.Name, w.Screen.get().Class, w.Screen.get().Scale),
            #issues == 0,
            table.concat(issues, "\n        ")
        )
    end
end

do
    local w, shell, mock, events = buildShell(DEVICES[5])
    shell:SetProfile(mock.Profile)
    shell:SetDots(mock.Dots)
    fire(find(shell.Main, "Nav_Play"), "Activated")
    check(
        "pressing PLAY asks to navigate and does not show a queue by itself",
        #events == 1 and events[1][2] == "Play" and find(shell.Top, "Queue") == nil
    )
    local dot = find(find(shell.Main, "Nav_Profile"), "Dot")
    check("a count over nine reads 9+", dot ~= nil and dot.Text == "9+", dot and dot.Text)
    check("a destination with nothing new has no dot", find(find(shell.Main, "Nav_Loadout"), "Dot") == nil)
    shell:SetQueue(mock.Queue)
    local text = find(shell.Top, "QueueText").Text
    check(
        "the queue strip states mode, team and time waited",
        text:find("TEAM DEATHMATCH 5V5", 1, true) and text:find("BLUE", 1, true) and text:find("0:42", 1, true),
        text
    )
    fire(find(shell.Top, "LeaveQueue"), "Activated")
    check(
        "LEAVE sends a request and the strip stays until the server answers",
        events[#events][1] == "leave" and find(shell.Top, "Queue") ~= nil
    )
    fire(find(shell.Main, "Wallet"), "Activated")
    check("the wallet can be pressed once the profile is in", events[#events][1] == "wallet")
    shell:SetActive("Shop")
    local shop = find(shell.Main, "Nav_Shop")
    check(
        "the active destination carries a mark, not only a colour",
        shop:GetAttribute("Active") == true and find(shop, "ActiveMark") ~= nil
    )
    shell:Toast("Saved.", "Good")
    check("a toast is drawn", find(shell.Top, "Toasts") ~= nil)
    for _, fn in w.Delayed do
        fn()
    end
    check("a toast goes away by itself", find(shell.Top, "Toasts") == nil)

    -- one Back rule
    local function screen(name)
        local made = w.CatalogScreen.new({ Name = name, Template = "Browser", Title = name, Tabs = MockCatalog.Tabs })
        made:SetItems(MockCatalog.items(NOW))
        return made
    end
    local first, second = screen("First"), screen("Second")
    w.ScreenStack.push(first)
    w.Input.Gamepad = true
    first.Focus = "filter"
    w.ScreenStack.push(second)
    check(
        "opening a second screen hides the first and keeps it",
        not first:IsOpen() and second:IsOpen() and w.ScreenStack.depth() == 2
    )
    w.ScreenStack.back()
    check(
        "Back returns to the first screen with focus where it was",
        first:IsOpen()
            and not second:IsOpen()
            and w.ScreenStack.depth() == 1
            and w.GuiService.SelectedObject ~= nil
            and w.GuiService.SelectedObject.Name == "Filter",
        w.GuiService.SelectedObject and w.GuiService.SelectedObject.Name
    )
    fire(find(first.Panel, "Close"), "Activated")
    check(
        "closing the last screen empties the stack and brings the nav back",
        w.ScreenStack.depth() == 0 and shell.MainGui.Enabled
    )
    w.ScreenStack.push(first)
    w.ScreenStack.push(second)
    w.ScreenStack.clear()
    check(
        "a match starting closes every screen at once",
        w.ScreenStack.depth() == 0 and not first:IsOpen() and not second:IsOpen()
    )

    local retried = 0
    local loading = w.CatalogScreen.new({
        Name = "Loading",
        Template = "Browser",
        Title = "SHOP",
        OnRetry = function()
            retried += 1
        end,
    })
    loading:Open()
    loading:SetLoad("Loading")
    check("a loading screen offers no retry", find(loading.Panel, "Retry") == nil)
    loading:SetLoad("Error", "Could not load the shop.")
    local retry = find(loading.Panel, "Retry")
    check(
        "an error states what happened and offers TRY AGAIN",
        retry ~= nil and find(loading.Panel, "StateText").Text == "Could not load the shop."
    )
    fire(retry, "Activated")
    check("TRY AGAIN asks the consumer to load again", retried == 1)
end

do
    -- a phone folds the optional destinations into MORE
    local _, shell, mock, events = buildShell(DEVICES[2])
    shell:SetProfile(mock.Profile)
    shell:SetDots(mock.Dots)
    local more = find(shell.Main, "Nav_More")
    check(
        "a small phone folds CUSTOMIZE and PROFILE into MORE",
        more ~= nil and find(shell.Main, "Nav_Customize") == nil and find(shell.Main, "Nav_Play") ~= nil
    )
    if more then
        fire(more, "Activated")
        local last = events[#events]
        check(
            "MORE carries the folded destinations and their counts",
            last[2] == "More" and table.concat(last[3], ",") == "Customize,Profile" and find(more, "Dot") ~= nil
        )
    end
end

do
    local w =
        world({ Name = "motion", Viewport = Vector2.new(1920, 1080), Touch = false, Inset = 36, ReducedMotion = true })
    check("reduced motion turns tween time to zero", w.Components.motion(0.3) == 0)
    w = world(DEVICES[5])
    check("motion keeps its time by default", w.Components.motion(0.3) == 0.3)
end

-- ===== 5. one way to build widgets =====
local RAW = { "ScreenGui", "TextButton", "TextLabel", "TextBox", "ImageButton", "ScrollingFrame" }
local BASELINE = "tools/ui_baseline.json"
local counts = {}
for _, name in fs.readDir("src/client/Controllers") do
    if name:sub(-4) == ".lua" then
        local source = fs.readFile("src/client/Controllers/" .. name)
        local widgets = 0
        for _, class in RAW do
            widgets += select(2, source:gsub('Instance%.new%("' .. class .. '"%)', ""))
        end
        local colours = select(2, source:gsub("Color3%.fromRGB", ""))
        if widgets > 0 or colours > 0 then
            counts[name] = { widgets = widgets, colours = colours }
        end
    end
end

if table.find(process.args, "--update-baseline") then
    local names = {}
    for name in counts do
        table.insert(names, name)
    end
    table.sort(names)
    local lines = { "{" }
    for index, name in names do
        lines[#lines + 1] = ('  "%s": { "widgets": %d, "colours": %d }%s'):format(
            name,
            counts[name].widgets,
            counts[name].colours,
            index < #names and "," or ""
        )
    end
    lines[#lines + 1] = "}"
    fs.writeFile(BASELINE, table.concat(lines, "\n") .. "\n")
    print("wrote " .. BASELINE)
end
local baseline = fs.isFile(BASELINE) and serde.decode("json", fs.readFile(BASELINE)) or {}
local grown, shrunk = {}, {}
for name, count in counts do
    local allowed = baseline[name] or { widgets = 0, colours = 0 }
    if count.widgets > allowed.widgets then
        table.insert(
            grown,
            ("%s: %d raw widgets, was %d. Build them with UI/Components."):format(name, count.widgets, allowed.widgets)
        )
    end
    if count.colours > allowed.colours then
        table.insert(
            grown,
            ("%s: %d Color3.fromRGB, was %d. Use a Theme token."):format(name, count.colours, allowed.colours)
        )
    end
    if count.widgets < allowed.widgets or count.colours < allowed.colours then
        table.insert(shrunk, name)
    end
end
table.sort(grown)
check("no controller adds raw widgets or colours beyond its baseline", #grown == 0, table.concat(grown, "\n        "))
if #shrunk > 0 then
    table.sort(shrunk)
    print("note  fewer raw widgets than the baseline in: " .. table.concat(shrunk, ", "))
    print("      lock that in with: lune run tools/check_ui.luau --update-baseline")
end

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    process.exit(1)
end
