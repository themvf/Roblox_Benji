-- Screen: the one place that knows how big the player's screen is and what parts of it the
-- player's thumbs, the notch and Roblox's own buttons already own. Every HUD in this game goes
-- through it, so a phone, an iPad and a desktop all get the same layout rules instead of each
-- controller inventing its own pixel offsets.
--
-- Why this exists: fixed `UDim2.fromOffset` panels sized for a 1920x1080 desktop window end up
-- stacked on top of each other (and on top of the crosshair) on a 812x375 phone, and anything
-- pinned to a screen edge disappears under an iPhone notch or the home indicator.
--
-- The rules it enforces (Roblox UI guidance, plus Apple/Android touch-target minimums):
--   * ScreenGuis declare `ScreenInsets = DeviceSafeInsets`, so scale/edge positions are relative
--     to the safe area rather than the raw screen, and pick a DisplayOrder from `Screen.Layers`.
--   * Panels keep their design pixel sizes but sit under a `UIScale` this module drives, so they
--     shrink on a phone and grow on a 4K monitor instead of overflowing or turning into stamps.
--   * Touch buttons are never smaller than `Screen.MIN_TAP` (44pt) after scaling.
--   * Nothing lives in `Screen.AimZone` (the middle of the screen) during play, and nothing on a
--     touch device lives in `Screen.ThumbLeft` / `Screen.ThumbRight`, which Roblox's movement
--     thumbstick, jump button and the Weapons Kit fire button already occupy.
--   * Everything re-reads the viewport on rotation, iPad Split View and window resizes via
--     `Screen.onChange`.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Screen = {}

-- One DisplayOrder table so layers stop fighting. Higher wins.
Screen.Layers = {
    Hud = 2, -- round state, timers, toasts
    Objective = 4, -- Convergence top bar and zone chips
    Meter = 6, -- mutation / jetpack meters
    Touch = 8, -- on-screen buttons: always above the readouts they drive
    Scoreboard = 15,
    Recap = 18,
    Celebration = 20,
    Modal = 30, -- loadout, kiosks: full-screen, blocks everything
}

-- Smallest comfortable touch target in points (Apple HIG 44pt, Material 48dp). Anything the
-- player taps mid-fight is measured against this after scaling.
Screen.MIN_TAP = 44

-- The layout is authored against this window and scaled from it.
local DESIGN = Vector2.new(1280, 720)

-- The smallest UIScale each device class can reach. Theme sizes text against the floor rather than
-- the current scale, so a label that is legible in one orientation stays legible after a rotation.
Screen.ScaleFloor = { Phone = 0.62, Tablet = 0.8, Desktop = 0.85, Console = 1 }

local listeners = {}

-- Device class. A laptop with a touchscreen keeps a keyboard, so it stays Desktop; an iPad with
-- a Magic Keyboard is still a Tablet, which is why size is checked before input.
local function classify(viewport)
    if GuiService:IsTenFootInterface() then
        return "Console"
    end
    if not UserInputService.TouchEnabled then
        return "Desktop"
    end
    if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        return "Desktop"
    end
    -- Roblox reports the window, not the panel, so use the short edge: an iPad mini in landscape
    -- is ~744 tall, every phone in landscape is under 500.
    return math.min(viewport.X, viewport.Y) >= 600 and "Tablet" or "Phone"
end

-- Scale factor for fixed-offset panels. Driven by the short edge so a tall phone does not get
-- desktop-sized panels squeezed into a 375 px height, and clamped so nothing becomes unreadable
-- or cartoonish. Phones get a floor: below it, 44pt targets no longer fit the design grid.
local function scaleFor(class, viewport)
    local raw = math.min(viewport.X / DESIGN.X, viewport.Y / DESIGN.Y)
    if class == "Phone" then
        return math.clamp(raw, Screen.ScaleFloor.Phone, 0.9)
    elseif class == "Tablet" then
        return math.clamp(raw, Screen.ScaleFloor.Tablet, 1.15)
    elseif class == "Console" then
        return math.clamp(raw * 1.1, Screen.ScaleFloor.Console, 1.6)
    end
    return math.clamp(raw, Screen.ScaleFloor.Desktop, 1.5)
end

-- Safe insets in *screen* pixels: the notch / rounded corners / home indicator reported by the
-- engine, plus the space Roblox's own chrome takes. `ScreenInsets = DeviceSafeInsets` handles the
-- device part for GUIs, but code that positions by hand (and the reserved zones below) needs the
-- numbers, and the top-left Roblox button + chat cluster is ours to avoid either way.
local function insetsFor(class, viewport, scale)
    local topLeft, bottomRight = GuiService:GetGuiInset()
    local top, bottom = topLeft.Y, bottomRight.Y
    -- TopbarInset reports the real chrome height including a notch; older clients lack it.
    local ok, topbar = pcall(function()
        return GuiService.TopbarInset
    end)
    if ok and topbar then
        top = math.max(top, topbar.Height)
    end
    -- The Roblox button, chat and menu pills live top-left and are wider on touch.
    local leadingTop = (class == "Phone" or class == "Tablet") and 360 * scale or 240 * scale
    return {
        Top = top + 8,
        Bottom = bottom + 8,
        Left = 12,
        Right = 12,
        -- Horizontal room, measured from the left edge, that the Roblox topbar already owns.
        TopbarLead = math.min(leadingTop, viewport.X * 0.4),
    }
end

-- Regions no HUD may occupy, as UDim2-friendly scale rectangles {x0, y0, x1, y1}.
local function zonesFor(class, viewport)
    local touch = class == "Phone" or class == "Tablet"
    -- The middle of the screen is where the player aims and where enemies appear. Keep the
    -- crosshair and the 3D read of the fight clear: banners go above it, meters below it.
    local aim = { 0.3, 0.28, 0.7, 0.72 }
    if not touch then
        return { Aim = aim, ThumbLeft = nil, ThumbRight = nil }
    end
    -- Roblox's movement thumbstick sits bottom-left; the jump button plus the Weapons Kit fire
    -- button stack in the bottom-right. Both grow with the screen, so measure them in scale.
    local wide = viewport.X >= 1000
    return {
        Aim = aim,
        ThumbLeft = { 0, wide and 0.6 or 0.5, wide and 0.26 or 0.34, 1 },
        ThumbRight = { wide and 0.78 or 0.7, wide and 0.55 or 0.45, 1, 1 },
    }
end

local state = {
    Class = "Desktop",
    Scale = 1,
    Viewport = DESIGN,
    Touch = false,
    Insets = { Top = 44, Bottom = 8, Left = 12, Right = 12, TopbarLead = 240 },
    Aim = { 0.3, 0.28, 0.7, 0.72 },
}

function Screen.get()
    return state
end

function Screen.isTouch()
    return state.Touch
end

local function recompute()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or DESIGN
    if viewport.X < 1 or viewport.Y < 1 then
        return false
    end
    local class = classify(viewport)
    local scale = scaleFor(class, viewport)
    local zones = zonesFor(class, viewport)
    local changed = state.Class ~= class or state.Scale ~= scale or state.Viewport ~= viewport
    state.Class = class
    state.Scale = scale
    state.Viewport = viewport
    state.Touch = class == "Phone" or class == "Tablet"
    state.Insets = insetsFor(class, viewport, scale)
    state.Aim = zones.Aim
    state.ThumbLeft = zones.ThumbLeft
    state.ThumbRight = zones.ThumbRight
    return changed
end

-- Run `fn(state)` now and again whenever the screen changes (rotation, Split View, a window
-- resize, a Bluetooth keyboard connecting). Returns a function that stops the subscription.
function Screen.onChange(fn)
    table.insert(listeners, fn)
    fn(state)
    return function()
        local i = table.find(listeners, fn)
        if i then
            table.remove(listeners, i)
        end
    end
end

local function fire()
    for _, fn in listeners do
        task.spawn(fn, state)
    end
end

-- A ScreenGui that already obeys the rules: safe-area aware, on a known layer, and surviving
-- respawns (HUDs are built once at KnitStart, not per character).
function Screen.newScreenGui(name, layer)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.DisplayOrder = layer or Screen.Layers.Hud
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    -- Keep scale positions and edge anchors inside the device's safe area: no content under an
    -- iPhone notch, the Dynamic Island or the home indicator.
    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    end)
    return gui
end

-- Attach a UIScale that tracks the screen. Every panel that uses pixel offsets needs one; it is
-- what turns one desktop-authored layout into a phone layout.
function Screen.autoScale(container, multiplier)
    local ui = container:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    ui.Parent = container
    Screen.onChange(function(s)
        ui.Scale = s.Scale * (multiplier or 1)
    end)
    return ui
end

-- Keep a panel inside the viewport no matter the design size: use with autoScale for panels that
-- are large on purpose (scoreboard, recap, loadout).
function Screen.fitWithin(frame, maxScaleX, maxScaleY)
    local constraint = frame:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
    constraint.Parent = frame
    Screen.onChange(function(s)
        constraint.MaxSize = Vector2.new(s.Viewport.X * (maxScaleX or 0.92), s.Viewport.Y * (maxScaleY or 0.92))
    end)
    return constraint
end

-- Size in pixels for something the player taps. `design` is the desktop-era size; the result is
-- scaled for the device but never drops below the 44pt minimum on touch.
function Screen.tapSize(design)
    local size = design * state.Scale
    if state.Touch then
        size = math.max(size, Screen.MIN_TAP)
    end
    return math.floor(size + 0.5)
end

-- True when a scale-space rectangle {x0,y0,x1,y1} overlaps a reserved zone. Used by the layout
-- self-check below; handy in tests and when hand-placing anything new.
function Screen.overlaps(rect, zone)
    if not zone then
        return false
    end
    return rect[1] < zone[3] and rect[3] > zone[1] and rect[2] < zone[4] and rect[4] > zone[2]
end

-- Warn (once per element) if a visible HUD element lands in the aim zone or under a thumb. This
-- is a development aid: it turns "the iPad looks wrong" into a named element in the output.
function Screen.audit(instance, label)
    if not instance:IsA("GuiObject") then
        return
    end
    local pos, size = instance.AbsolutePosition, instance.AbsoluteSize
    local v = state.Viewport
    if v.X < 1 or v.Y < 1 or size.X < 1 then
        return
    end
    local rect = { pos.X / v.X, pos.Y / v.Y, (pos.X + size.X) / v.X, (pos.Y + size.Y) / v.Y }
    for _, zone in { { "aim zone", state.Aim }, { "left thumb", state.ThumbLeft }, { "right thumb", state.ThumbRight } } do
        if Screen.overlaps(rect, zone[2]) then
            warn(("[Screen] %s overlaps the %s on %s"):format(label or instance:GetFullName(), zone[1], state.Class))
        end
    end
end

function Screen.start()
    if Screen._started then
        return Screen
    end
    Screen._started = true
    recompute()
    local function refresh()
        if recompute() then
            fire()
        end
    end
    local function watchCamera()
        local camera = Workspace.CurrentCamera
        if camera then
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
        end
    end
    watchCamera()
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        watchCamera()
        refresh()
    end)
    -- A Bluetooth keyboard or controller connecting mid-session flips the device class.
    UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refresh)
    UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh)
    UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(refresh)
    pcall(function()
        GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refresh)
    end)
    return Screen
end

return Screen
