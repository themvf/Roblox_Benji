-- Weapon test range HUD: the gun picker, the hit readout, damage popups on the dummies, and the
-- client half of infinite ammo. Everything here is off unless the server has set InRange on the
-- local player (RangeService does, on entry, and clears it when they leave).
--
-- Layout (Screen zones):
--   readout     top-right, under the topbar inset -- clear of the crosshair and the jump cluster
--   WEAPONS     touch only, left edge between the topbar and the thumbstick
--   picker      centred modal on the Modal layer; frees the cursor the Weapons Kit locks
-- Controls: G / gamepad Y opens the picker, [ and ] / d-pad left-right cycle guns.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Range = require(ReplicatedStorage.Shared.Range)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Theme = require(script.Parent.Parent.UI.Theme)
local Screen = require(script.Parent.Parent.UI.Screen)

local RangeController = Knit.CreateController({ Name = "RangeController" })

local C = Theme.Color
local ZONE_TEXT = { FULL = "full damage", FALLOFF = "in falloff", FLOOR = "past dropoff end" }
local ZONE_COLOR = { FULL = C.Good, FALLOFF = C.Accent, FLOOR = C.Warn }

local function localPlayer()
    return Players.LocalPlayer
end

local function inRange()
    return localPlayer():GetAttribute("InRange") == true
end

local function tuning(key)
    local t = ReplicatedStorage:FindFirstChild("Tuning")
    local v = t and t:GetAttribute("Range_" .. key)
    return type(v) == "number" and v > 0 and v or Config.Range[key]
end

-- "AssaultRifle" -> "ASSAULT RIFLE"
local function display(name)
    return (name:gsub("(%l)(%u)", "%1 %2")):upper()
end

local function fmt(n)
    return ("%.1f"):format(n)
end

local function corner(inst, radius)
    local ui = Instance.new("UICorner")
    ui.CornerRadius = UDim.new(0, radius or 10)
    ui.Parent = inst
end

local function text(parent, props)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = props.Font or Enum.Font.GothamBold
    label.TextSize = Theme.textSize(props.Size or Theme.Type.Body)
    label.TextColor3 = props.Color or C.Text
    label.TextXAlignment = props.Align or Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Text = props.Text or ""
    label.Size = props.UDim or UDim2.new(1, 0, 0, 20)
    label.LayoutOrder = props.Order or 0
    label.Parent = parent
    return label
end

local function button(parent, label, color)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = color or C.PanelHigh
    b.AutoButtonColor = true
    b.Font = Enum.Font.GothamBlack
    b.TextSize = Theme.textSize(Theme.Type.Body)
    b.TextColor3 = C.Text
    b.Text = label
    b.Parent = parent
    corner(b, 8)
    return b
end

-- ===== Readout =====

function RangeController:BuildReadout()
    local gui = Screen.newScreenGui("RangeHud", Screen.Layers.Hud)
    gui.Enabled = false
    gui.Parent = localPlayer():WaitForChild("PlayerGui")
    self.Hud = gui

    local panel = Instance.new("Frame")
    panel.Name = "Readout"
    panel.AnchorPoint = Vector2.new(1, 0)
    panel.Size = UDim2.fromOffset(330, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.BackgroundColor3 = C.Panel
    panel.BackgroundTransparency = Theme.Transparency.Panel
    panel.Parent = gui
    corner(panel, 12)
    Screen.autoScale(panel)
    local pad = Instance.new("UIPadding")
    for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
        pad[side] = UDim.new(0, 12)
    end
    pad.Parent = panel
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 4)
    list.Parent = panel

    self.Lines = {
        Weapon = text(panel, { Size = Theme.Type.Title, Font = Enum.Font.GothamBlack, Color = C.Accent, Order = 1 }),
        Hit = text(panel, { Size = Theme.Type.Title, Font = Enum.Font.GothamBlack, Order = 2 }),
        Where = text(panel, { Order = 3, Color = C.TextMuted }),
        Falloff = text(panel, { Order = 4 }),
        Spec = text(panel, { Order = 5, Color = C.TextMuted }),
        Dummy = text(panel, { Order = 6 }),
        Card = text(panel, {
            Order = 7,
            Size = Theme.Type.Label,
            Color = C.TextMuted,
            UDim = UDim2.new(1, 0, 0, 0),
        }),
        Hint = text(panel, { Order = 8, Size = Theme.Type.Label, Color = C.Accent }),
    }
    self.Lines.Card.AutomaticSize = Enum.AutomaticSize.Y
    self.Lines.Hit.Text = "Shoot a dummy"

    -- Touch has no G key: a WEAPONS button on the left edge opens the picker.
    local open = button(gui, "WEAPONS", C.PanelRaised)
    open.Name = "OpenPicker"
    open.AnchorPoint = Vector2.new(0, 0.5)
    open.TextColor3 = C.Accent
    open.Activated:Connect(function()
        self:OpenPicker()
    end)
    self.OpenButton = open

    Screen.onChange(function(s)
        panel.Position = UDim2.new(1, -(s.Insets.Right + 12), 0, s.Insets.Top + 12)
        open.Visible = s.Touch
        open.Size = UDim2.fromOffset(Screen.tapSize(120), Screen.tapSize(48))
        open.Position = UDim2.new(0, s.Insets.Left + 12, 0.38, 0)
        self:RefreshHint()
    end)
end

function RangeController:RefreshHint()
    if not self.Lines then
        return
    end
    local hint
    if Screen.isTouch() then
        hint = "Tap WEAPONS to switch guns"
    elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
        hint = "Y  pick a gun     D-pad  cycle"
    else
        hint = "G  pick a gun     [ ]  cycle"
    end
    self.Lines.Hint.Text = hint
end

function RangeController:ShowWeapon(name)
    local stats = name and Weapons[name]
    if not stats then
        return
    end
    self.Lines.Weapon.Text = display(name)
    local d = Range.describe(stats)
    self.Lines.Card.Text = table.concat({ d.Damage, d.Crit, d.Dropoff, d.Rate }, "\n")
end

-- One shot's worth of pellets on one dummy, as the readout and the popup show it.
function RangeController:ShowShot(shot)
    local r = shot.Last
    local stats = Weapons[r.Weapon]
    local pellets = stats and stats.Pellets or 1
    local L = self.Lines
    if shot.Count > 1 or pellets > 1 then
        L.Hit.Text = ("%s  %d/%d pellets%s"):format(
            fmt(shot.Sum),
            shot.Count,
            pellets,
            shot.Heads > 0 and ("  (%d head)"):format(shot.Heads) or ""
        )
    else
        L.Hit.Text = (r.Headshot and "CRIT  " or "BODY  ") .. fmt(r.Damage)
    end
    L.Hit.TextColor3 = shot.Heads > 0 and C.Accent or C.Text
    L.Where.Text = ("%s studs  -  %d %s lane"):format(fmt(r.Distance), r.Marked, r.Band)
    L.Falloff.Text = ("%d%% of max  -  %s"):format(math.floor(shot.Falloff / shot.Count * 100 + 0.5), ZONE_TEXT[r.Zone])
    L.Falloff.TextColor3 = ZONE_COLOR[r.Zone]
    -- Spec is the Shared/Weapons number; the kit's linear-to-zero falloff can land under it.
    local off = math.abs(r.Damage - r.Spec) > math.max(0.05, r.Spec * 0.03)
    L.Spec.Text = ("spec %s per pellet%s"):format(fmt(r.Spec), off and "  (kit differs)" or "")
    L.Spec.TextColor3 = off and C.Warn or C.TextMuted
    if r.Down then
        L.Dummy.Text = ("DOWN in %.2f s  -  %d hits"):format(r.TTK or 0, r.Hits)
        L.Dummy.TextColor3 = C.Good
    else
        L.Dummy.Text = ("dummy %d / %d"):format(math.ceil(r.Health), r.MaxHealth)
        L.Dummy.TextColor3 = C.Text
    end
    self:ShowWeapon(r.Weapon)
end

-- ===== Popups =====

-- A number that rises off the dummy's head and fades. Sized in studs, grown with the lane's
-- distance so the far dummies' numbers still read from the firing line.
function RangeController:Popup(shot)
    local r = shot.Last
    local head = r.Head
    if not head or not head.Parent then
        return
    end
    local gui = shot.Popup
    if not gui then
        local grow = math.max(1, r.Marked / 50)
        gui = Instance.new("BillboardGui")
        gui.Name = "RangePopup"
        gui.Size = UDim2.fromScale(5 * grow, 1.8 * grow)
        gui.StudsOffset = Vector3.new((math.random() - 0.5) * grow, 3.2 * grow, 0)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 320
        gui.Adornee = head
        -- a BillboardGui only renders under PlayerGui itself, not inside a ScreenGui
        gui.Parent = localPlayer():WaitForChild("PlayerGui")
        local label = Instance.new("TextLabel")
        label.Name = "Value"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextScaled = true
        label.Font = Enum.Font.GothamBlack
        Theme.overWorld(label)
        label.Parent = gui
        shot.Popup = gui
        task.delay(0.35, function()
            local rise = TweenService:Create(
                gui,
                TweenInfo.new(0.6),
                { StudsOffset = gui.StudsOffset + Vector3.new(0, 1.5 * grow, 0) }
            )
            TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
            local stroke = label:FindFirstChildOfClass("UIStroke")
            if stroke then
                TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
            end
            rise:Play()
            rise.Completed:Wait()
            gui:Destroy()
        end)
    end
    local label = gui.Value
    label.Text = (shot.Heads > 0 and "CRIT " or "") .. fmt(shot.Sum) .. (r.Down and "  DOWN" or "")
    label.TextColor3 = shot.Heads > 0 and C.Accent or C.Text
end

function RangeController:OnHit(r)
    if not inRange() then
        return
    end
    local now = os.clock()
    local shot = self.Shots[r.Lane]
    if not shot or now - shot.Started > tuning("PelletWindow") then
        shot = { Started = now, Count = 0, Sum = 0, Heads = 0, Falloff = 0 }
        self.Shots[r.Lane] = shot
    end
    shot.Count += 1
    shot.Sum += r.Damage
    shot.Falloff += r.Falloff
    if r.Headshot then
        shot.Heads += 1
    end
    shot.Last = r
    self:ShowShot(shot)
    self:Popup(shot)
end

-- ===== Picker =====

function RangeController:BuildPicker()
    local gui = Screen.newScreenGui("RangePicker", Screen.Layers.Modal)
    gui.Enabled = false
    gui.Parent = localPlayer():WaitForChild("PlayerGui")
    self.PickerGui = gui

    local scrim = Instance.new("Frame")
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.BackgroundColor3 = C.Panel
    scrim.BackgroundTransparency = Theme.Transparency.Scrim
    scrim.Parent = gui

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(760, 500)
    panel.BackgroundColor3 = C.PanelRaised
    panel.Parent = gui
    corner(panel, 14)
    Screen.autoScale(panel)
    Screen.fitWithin(panel, 0.94, 0.9)
    local pad = Instance.new("UIPadding")
    for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
        pad[side] = UDim.new(0, 16)
    end
    pad.Parent = panel

    text(panel, {
        Text = "WEAPON RANGE",
        Size = Theme.Type.Title,
        Font = Enum.Font.GothamBlack,
        Color = C.Accent,
        UDim = UDim2.new(1, -240, 0, 28),
    })
    text(panel, {
        Text = "Pick a gun. Ammo never runs out here.",
        Size = Theme.Type.Label,
        Color = C.TextMuted,
        UDim = UDim2.new(1, -240, 0, 18),
    }).Position =
        UDim2.fromOffset(0, 30)

    local leave = button(panel, "BACK TO LOBBY")
    leave.AnchorPoint = Vector2.new(1, 0)
    leave.Position = UDim2.new(1, -84, 0, 0)
    leave.Size = UDim2.fromOffset(150, 48)
    leave.Activated:Connect(function()
        self:ClosePicker()
        Knit.GetService("RangeService"):Leave()
    end)
    local close = button(panel, "X")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, 0, 0, 0)
    close.Size = UDim2.fromOffset(72, 48)
    close.Activated:Connect(function()
        self:ClosePicker()
    end)
    self.CloseButton = close

    local grid = Instance.new("ScrollingFrame")
    grid.Position = UDim2.fromOffset(0, 64)
    grid.Size = UDim2.new(1, 0, 1, -64)
    grid.BackgroundTransparency = 1
    grid.BorderSizePixel = 0
    grid.ScrollBarThickness = 6
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.CanvasSize = UDim2.new()
    grid.Parent = panel
    local layout = Instance.new("UIGridLayout")
    -- 72 design px tall clears the 44pt tap floor at the phone's smallest UIScale (0.62)
    layout.CellSize = UDim2.fromOffset(234, 72)
    layout.CellPadding = UDim2.fromOffset(10, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid

    self.Cells = {}
    for i, name in self.Guns do
        local stats = Weapons[name]
        local cell = button(grid, "")
        cell.Name = name
        cell.LayoutOrder = i
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 3
        stroke.Color = C.Accent
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Enabled = false
        stroke.Parent = cell
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 6, 1, 0)
        bar.BackgroundColor3 = Theme.Slot[stats.Slot] or C.TextMuted
        bar.BorderSizePixel = 0
        bar.Parent = cell
        corner(bar, 3)
        local title = text(cell, {
            Text = display(name),
            Font = Enum.Font.GothamBlack,
            UDim = UDim2.new(1, -20, 0, 22),
        })
        title.Position = UDim2.fromOffset(14, 8)
        local d = Range.describe(stats)
        local sub = text(cell, {
            Text = stats.Slot:upper() .. "  -  " .. d.Damage,
            Size = Theme.Type.Label,
            Color = C.TextMuted,
            UDim = UDim2.new(1, -20, 0, 34),
        })
        sub.Position = UDim2.fromOffset(14, 32)
        sub.TextYAlignment = Enum.TextYAlignment.Top
        cell.Activated:Connect(function()
            self:Equip(name)
            self:ClosePicker()
        end)
        self.Cells[name] = stroke
    end
end

function RangeController:RefreshPicker()
    local current = localPlayer():GetAttribute("RangeWeapon")
    for name, stroke in self.Cells or {} do
        stroke.Enabled = name == current
    end
end

function RangeController:OpenPicker()
    if not inRange() or not self.PickerGui or self.PickerGui.Enabled then
        return
    end
    self:RefreshPicker()
    self.PickerGui.Enabled = true
    -- the Weapons Kit re-locks the cursor every frame while a gun is out; win the frame
    RunService:BindToRenderStep("RangePickerMouse", Enum.RenderPriority.Last.Value, function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    if UserInputService.GamepadEnabled then
        local current = localPlayer():GetAttribute("RangeWeapon")
        local stroke = current and self.Cells[current]
        GuiService.SelectedObject = stroke and stroke.Parent or self.CloseButton
    end
end

function RangeController:ClosePicker()
    if not self.PickerGui or not self.PickerGui.Enabled then
        return
    end
    self.PickerGui.Enabled = false
    RunService:UnbindFromRenderStep("RangePickerMouse")
    GuiService.SelectedObject = nil
end

function RangeController:Equip(name)
    Knit.GetService("RangeService"):Equip(name)
end

function RangeController:Cycle(step)
    local current = localPlayer():GetAttribute("RangeWeapon")
    local i = table.find(self.Guns, current) or 0
    local n = #self.Guns
    if n == 0 then
        return
    end
    self:Equip(self.Guns[(i - 1 + step) % n + 1])
end

-- ===== Infinite ammo, client half =====

-- The kit spends a round from the client's own copy of CurrentAmmo before it tells the server,
-- and reloads when that copy hits zero. Keep it full while in range; RangeService does the
-- server copy.
function RangeController:WatchTool(tool)
    if not tool:IsA("Tool") then
        return
    end
    task.spawn(function()
        local ammo = tool:WaitForChild("CurrentAmmo", 10)
        local config = tool:FindFirstChild("Configuration")
        local capacity = config and config:FindFirstChild("AmmoCapacity")
        if not ammo or not capacity then
            return
        end
        local conn = ammo.Changed:Connect(function()
            if inRange() and ammo.Value < capacity.Value then
                ammo.Value = capacity.Value
            end
        end)
        tool.Destroying:Once(function()
            conn:Disconnect()
        end)
    end)
end

function RangeController:WatchCharacter(character)
    character.ChildAdded:Connect(function(child)
        if not self.Watched[child] then
            self.Watched[child] = true
            self:WatchTool(child)
        end
    end)
end

-- ===== Lifecycle =====

function RangeController:Refresh()
    local on = inRange()
    self.Hud.Enabled = on
    if not on then
        self:ClosePicker()
    end
end

function RangeController:KnitStart()
    self.Shots = {}
    self.Watched = setmetatable({}, { __mode = "k" })
    self.Guns = {}
    self:BuildReadout()

    local service = Knit.GetService("RangeService")
    service:GetGuns():andThen(function(guns)
        self.Guns = guns
        self:BuildPicker()
    end)
    service.Hit:Connect(function(report)
        self:OnHit(report)
    end)

    local player = localPlayer()
    player:GetAttributeChangedSignal("InRange"):Connect(function()
        self:Refresh()
    end)
    player:GetAttributeChangedSignal("RangeWeapon"):Connect(function()
        self:ShowWeapon(player:GetAttribute("RangeWeapon"))
        self:RefreshPicker()
    end)
    self:Refresh()

    player.CharacterAdded:Connect(function(c)
        self:WatchCharacter(c)
    end)
    if player.Character then
        self:WatchCharacter(player.Character)
    end

    UserInputService.LastInputTypeChanged:Connect(function()
        self:RefreshHint()
    end)
    UserInputService.InputBegan:Connect(function(input, processed)
        if not inRange() then
            return
        end
        local key = input.KeyCode
        if self.PickerGui and self.PickerGui.Enabled then
            if key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.G then
                self:ClosePicker()
            end
            return
        end
        if processed then
            return
        end
        if key == Enum.KeyCode.G or key == Enum.KeyCode.ButtonY then
            self:OpenPicker()
        elseif key == Enum.KeyCode.LeftBracket or key == Enum.KeyCode.DPadLeft then
            self:Cycle(-1)
        elseif key == Enum.KeyCode.RightBracket or key == Enum.KeyCode.DPadRight then
            self:Cycle(1)
        end
    end)
end

return RangeController
