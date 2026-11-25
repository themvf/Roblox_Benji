-- Weapon hotbar. Replaces Roblox's built-in Backpack CoreGui, which renders Tool NAMES in small
-- boxes -- the source of "AssaultRifl..." truncating and of the whole bar reading as developer UI.
--
-- Icons are ViewportFrames showing each weapon's own 3D model. Tool.TextureId would be the normal
-- route but it needs uploaded image assets, and the models are already in the place, so this gets
-- real per-weapon icons with nothing to upload and nothing to keep in sync.
--
-- Disabling the core Backpack also disables its number-key handling, so equipping is implemented
-- here: 1/2/3 and clicks both go through Equip().
--
-- Rivals-style: the slot IS the icon. No weapon names (the model says which gun it is), a small
-- key number in the corner on keyboard only, and an outline on the one in your hands. Health
-- and ammo sit just above the row (VitalsController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local WeaponPreview = require(ReplicatedStorage.Shared.WeaponPreview)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local WeaponBarController = Knit.CreateController({ Name = "WeaponBarController" })

local SLOT = Theme.Color.Panel
local SLOT_ON = Theme.Color.PanelSelected
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local ACCENT = Theme.Color.Accent

local SLOT_SIZE = 80
local SLOT_HEIGHT = 60
WeaponBarController.SLOT_HEIGHT = SLOT_HEIGHT
WeaponBarController.BOTTOM_GAP = 10 -- row's distance above the bottom safe-area inset
local SLOT_ORDER = { Primary = 1, Secondary = 2, Melee = 3, Utility = 4 }
local NUMBER_KEY = {
    [Enum.KeyCode.One] = 1,
    [Enum.KeyCode.Two] = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four] = 4,
    [Enum.KeyCode.Five] = 5,
}

local function player()
    return Players.LocalPlayer
end

-- Frame a model inside a ViewportFrame: one camera per slot, pulled back to fit the extents.
local function makeIcon(parent: Instance, tool: Tool)
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(1, -12, 1, -12)
    vp.Position = UDim2.fromOffset(6, 6)
    vp.BackgroundTransparency = 1
    vp.Ambient = Color3.fromRGB(200, 210, 225)
    vp.LightColor = Color3.fromRGB(255, 245, 225)
    vp.Parent = parent

    -- Invisible handles, hitboxes and effect parts must not push the preview camera back.
    -- Read all visible parts, including tools whose geometry is not inside the first Model.
    local clone = Instance.new("Model")
    clone.Name = "Preview"
    local handle = tool:FindFirstChild("Handle")
    local origin = handle and handle:IsA("BasePart") and handle.CFrame or CFrame.identity
    for _, part in tool:GetDescendants() do
        if part:IsA("BasePart") and part.Transparency < 0.95 and part.Archivable then
            local copy = part:Clone()
            for _, child in copy:GetDescendants() do
                if
                    child:IsA("BasePart")
                    or child:IsA("LuaSourceContainer")
                    or child:IsA("JointInstance")
                    or child:IsA("Constraint")
                    or child:IsA("ParticleEmitter")
                    or child:IsA("Trail")
                    or child:IsA("Beam")
                    or child:IsA("Light")
                then
                    child:Destroy()
                end
            end
            copy.Anchored = true
            copy.CanCollide = false
            copy.CFrame = origin:ToObjectSpace(part.CFrame)
            copy.Parent = clone
        end
    end
    if #clone:GetChildren() == 0 then
        clone:Destroy()
        -- nothing visible to frame: the name is the fallback
        local name = Instance.new("TextLabel")
        name.Size = UDim2.fromScale(1, 1)
        name.BackgroundTransparency = 1
        name.Text = (tool.Name:gsub("(%l)(%u)", "%1 %2")):upper()
        name.TextScaled = true
        name.Font = Enum.Font.GothamBold
        name.TextColor3 = TEXT
        name.Parent = vp
        return vp
    end
    clone.Parent = vp

    local cam = Instance.new("Camera")
    cam.Parent = vp
    cam.FieldOfView = 35
    vp.CurrentCamera = cam

    local cf, size = clone:GetBoundingBox()
    local direction = size.X >= size.Z and Vector3.new(0.15, 0.3, 1) or Vector3.new(1, 0.3, 0.15)
    local basis = CFrame.lookAt(cf.Position + direction, cf.Position)
    local half = size / 2
    local function extent(axis)
        local localAxis = cf:VectorToObjectSpace(axis)
        return math.abs(localAxis.X) * half.X + math.abs(localAxis.Y) * half.Y + math.abs(localAxis.Z) * half.Z
    end
    local function fit()
        local aspect = vp.AbsoluteSize.X / math.max(1, vp.AbsoluteSize.Y)
        local dist = WeaponPreview.distance(
            extent(basis.RightVector),
            extent(basis.UpVector),
            extent(basis.LookVector),
            aspect,
            cam.FieldOfView
        )
        cam.CFrame = CFrame.lookAt(cf.Position + direction.Unit * dist, cf.Position)
    end
    vp:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    fit()
    return vp
end

function WeaponBarController:BuildGui()
    local gui = Screen.newScreenGui("WeaponBar", Screen.Layers.Hotbar)
    gui.Parent = player():WaitForChild("PlayerGui")
    self.Gui = gui

    local row = Instance.new("Frame")
    row.AnchorPoint = Vector2.new(0.5, 1)
    row.Size = UDim2.fromOffset(400, SLOT_HEIGHT)
    row.BackgroundTransparency = 1
    row.Parent = gui
    self.Row = row
    Screen.onChange(function(state)
        row.Position = UDim2.new(0.5, 0, 1, -state.Insets.Bottom - WeaponBarController.BOTTOM_GAP)
        self:Rebuild()
    end)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:Resize()
    end)
end

function WeaponBarController:Resize()
    local available = self.Gui.AbsoluteSize.X - 220 -- reserve the touch movement/jump corners
    local count = math.max(1, #(self.Slots or {}))
    local width = math.clamp(math.floor((available - (count - 1) * 6) / count), 64, SLOT_SIZE)
    self.Row.Size = UDim2.fromOffset(count * (width + 6) - 6, SLOT_HEIGHT)
    for _, button in self.Slots or {} do
        button.Size = UDim2.fromOffset(width, SLOT_HEIGHT)
    end
end

function WeaponBarController:Tools(): { Tool }
    local out = {}
    local backpack = player():FindFirstChildOfClass("Backpack")
    local character = player().Character
    for _, container in { character, backpack } do
        if container then
            for _, t in container:GetChildren() do
                if t:IsA("Tool") then
                    table.insert(out, t)
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local aSlot = SLOT_ORDER[(Weapons[a.Name] or {}).Slot] or 5
        local bSlot = SLOT_ORDER[(Weapons[b.Name] or {}).Slot] or 5
        return aSlot < bSlot or (aSlot == bSlot and a.Name < b.Name)
    end)
    return out
end

function WeaponBarController:Equip(index: number)
    local tools = self:Tools()
    local tool = tools[index]
    local character = player().Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not tool or not humanoid or humanoid.Health <= 0 or player():GetAttribute("MapVoteOpen") then
        return
    end
    if tool.Parent ~= character then
        humanoid:EquipTool(tool)
    end
end

function WeaponBarController:Rebuild()
    self.Row:ClearAllChildren()
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = self.Row

    self.Slots = {}
    local character = player().Character
    local touch = Knit.GetController("TouchController").IsTouch() -- honours Debug_ForceTouchUi
    for i, tool in self:Tools() do
        local held = tool.Parent == character
        local btn = Instance.new("TextButton")
        btn.Name = tool.Name
        btn.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_HEIGHT)
        btn.BackgroundColor3 = held and SLOT_ON or SLOT
        btn.BackgroundTransparency = held and 0.05 or Theme.Transparency.Panel
        btn.AutoButtonColor = false
        btn.Text = ""
        btn.LayoutOrder = i
        btn.Parent = self.Row
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = btn
        if held then
            local ring = Instance.new("UIStroke")
            ring.Thickness = 2
            ring.Color = ACCENT
            ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            ring.Parent = btn
        end

        makeIcon(btn, tool)

        -- keyboard only: a touch player taps the slot, and the number is noise there
        if not touch then
            local key = Instance.new("TextLabel")
            key.Position = UDim2.fromOffset(5, 3)
            key.Size = UDim2.fromOffset(14, 14)
            key.BackgroundTransparency = 1
            key.Text = tostring(i)
            key.TextSize = Theme.textSize(Theme.Type.Label)
            key.Font = Enum.Font.GothamBold
            key.TextColor3 = held and TEXT or MUTED
            key.TextXAlignment = Enum.TextXAlignment.Left
            key.ZIndex = 2
            key.Parent = btn
        end

        btn.Activated:Connect(function()
            self:Equip(i)
        end)
        self.Slots[i] = btn
    end
    self.Gui.Enabled = #self:Tools() > 0
    self:Resize()
end

function WeaponBarController:Watch(container: Instance)
    if not container then
        return
    end
    self.Watched = self.Watched or setmetatable({}, { __mode = "k" })
    if self.Watched[container] then
        return
    end
    self.Watched[container] = true
    container.ChildAdded:Connect(function(c)
        if c:IsA("Tool") then
            self:QueueRebuild()
        end
    end)
    container.ChildRemoved:Connect(function(c)
        if c:IsA("Tool") then
            self:QueueRebuild()
        end
    end)
end

-- equipping moves a Tool between two containers, firing several events: coalesce them
function WeaponBarController:QueueRebuild()
    self.Dirty = true
    if self.Pending then
        return
    end
    self.Pending = true
    task.defer(function()
        task.wait(0.05)
        self.Pending = false
        if self.Dirty then
            self.Dirty = false
            self:Rebuild()
        end
    end)
end

function WeaponBarController:KnitStart()
    self:BuildGui()
    -- our bar replaces the core one; leaving both on would show two hotbars
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    end)

    local function onCharacter(character)
        self:Watch(character)
        self:Watch(player():FindFirstChildOfClass("Backpack"))
        self:QueueRebuild()
    end
    if player().Character then
        onCharacter(player().Character)
    end
    player().CharacterAdded:Connect(onCharacter)
    player().ChildAdded:Connect(function(c)
        if c:IsA("Backpack") then
            self:Watch(c)
            self:QueueRebuild()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if player():GetAttribute("MapVoteOpen") then
            return -- the map vote owns the number keys while it is on screen
        end
        local n = NUMBER_KEY[input.KeyCode]
        if n then
            self:Equip(n)
        elseif input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonL1 then
            local inventory = self:Tools()
            if #inventory > 0 then
                local current = 1
                for i, tool in inventory do
                    if tool.Parent == player().Character then
                        current = i
                        break
                    end
                end
                local step = input.KeyCode == Enum.KeyCode.ButtonR1 and 1 or -1
                self:Equip((current - 1 + step) % #inventory + 1)
            end
        end
    end)
end

return WeaponBarController
