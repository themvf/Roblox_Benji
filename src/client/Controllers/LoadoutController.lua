-- Slot-first lobby equipment and customization browser. The physical Armory prompt and
-- persistent lobby navigation both open this same screen.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)
local Celebrations = require(ReplicatedStorage.Shared.Celebrations)
local Skins = require(ReplicatedStorage.Shared.Skins)
local WeaponPreview = require(ReplicatedStorage.Shared.WeaponPreview)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local LoadoutController = Knit.CreateController({ Name = "LoadoutController" })

local PANEL = Color3.fromRGB(28, 30, 38)
local PANEL_LIGHT = Color3.fromRGB(44, 47, 58)
local PANEL_SELECTED = Color3.fromRGB(62, 66, 82)
local ACCENT = Color3.fromRGB(255, 200, 70)
local TEXT = Color3.fromRGB(245, 245, 250)
local MUTED = Color3.fromRGB(160, 165, 180)
local RED = Color3.fromRGB(255, 105, 105)
local LOADOUT_SLOTS = { "Primary", "Secondary", "Melee", "Utility", "AlterEgo" }
local CUSTOMIZE_CATEGORIES = { "Celebration", "Skins" }
local NONE = "__NONE__"
local DEFAULT_SKIN = "__DEFAULT__"

local SLOT_COLORS = {
    Primary = Color3.fromRGB(80, 230, 120),
    Secondary = Color3.fromRGB(80, 150, 255),
    Melee = Color3.fromRGB(255, 120, 90),
    Utility = Color3.fromRGB(200, 120, 255),
    AlterEgo = Color3.fromRGB(255, 120, 40),
    Celebration = ACCENT,
    Skins = Color3.fromRGB(90, 205, 220),
}

local TIER_COLORS = {
    Common = Color3.fromRGB(180, 185, 195),
    Uncommon = Color3.fromRGB(90, 200, 120),
    Rare = Color3.fromRGB(80, 150, 255),
    Legendary = Color3.fromRGB(255, 160, 60),
    Mythical = Color3.fromRGB(230, 80, 255),
}

local CELEBRATION_GLYPHS = {
    cel_common_cheer = "CHEER",
    cel_common_laugh = "HA!",
    cel_common_point = "POINT",
    cel_common_wave = "WAVE",
    cel_leg_flag = "FLAG",
    cel_myth_fireworks = "BOOM",
    cel_rare_confetti = "PARTY",
    cel_rare_spotlight = "STAR",
}

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
    ui.TextSize = 17
    ui.Font = Enum.Font.GothamBold
    ui.Selectable = true
    ui.Parent = parent
    corner(ui, 10)
    return ui
end

local function pretty(value)
    if not value then
        return "NONE"
    end
    return value:gsub("(%l)(%u)", "%1 %2"):upper()
end

local function clearGuiObjects(parent)
    for _, child in parent:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

local function statLines(stats)
    if stats.Type == "Utility" then
        return {
            ("Fuel %s  |  Burn %s/s"):format(stats.Fuel, stats.Burn),
            ("Recharge %s/s  |  Lift %s studs/s"):format(stats.Recharge, stats.Thrust),
            "Hold Jump to fly",
        }
    end
    if stats.Type == "Melee" then
        return {
            ("Damage %s  |  Reach %s studs"):format(stats.Damage[1], stats.Range),
            ("Arc %s deg  |  Swing %.2fs"):format(stats.Arc, stats.Cooldown),
            "No ammunition required",
        }
    end
    local shotDamage = stats.Damage[1] * stats.Pellets
    local dps = shotDamage / stats.Cooldown
    if stats.Burst then
        dps = (shotDamage * stats.Burst) / stats.Cooldown
    end
    local magazine = stats.Ammo[1] == math.huge and "Infinite" or tostring(stats.Ammo[1])
    local mode = stats.Burst and ("Burst x" .. stats.Burst) or (stats.Auto and "Automatic" or "Semi-auto")
    return {
        ("Damage %s%s  |  Headshot %s"):format(
            stats.Damage[1],
            stats.Pellets > 1 and (" x" .. stats.Pellets) or "",
            stats.Crit[1] * stats.Pellets
        ),
        ("DPS %d  |  Magazine %s"):format(dps, magazine),
        ("%s  |  Reload %.2fs"):format(mode, stats.Reload),
    }
end

local function previewColor(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function applyPreviewSkin(model, skinId)
    local skin = skinId and Skins.get(skinId)
    local texture = skin and skin.Systems.Texture
    if not texture then
        return
    end
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            local rule = texture.Overrides and texture.Overrides[descendant.Name] or texture.Body
            if rule then
                if rule.Color then
                    descendant.Color = previewColor(rule.Color)
                end
                if rule.Material and Enum.Material[rule.Material] then
                    descendant.Material = Enum.Material[rule.Material]
                end
                if rule.Reflectance then
                    descendant.Reflectance = rule.Reflectance
                end
            end
        end
    end
end

local function cloneWeaponModel(weaponName, parent, skinId)
    local tool = ReplicatedStorage:FindFirstChild("WeaponTools")
    tool = tool and tool:FindFirstChild(weaponName)
    local source = tool and tool:FindFirstChildOfClass("Model")
    if not source then
        return nil
    end
    local model = source:Clone()
    for _, descendant in model:GetDescendants() do
        if
            descendant:IsA("Script")
            or descendant:IsA("LocalScript")
            or descendant:IsA("Sound")
            or descendant:IsA("Beam")
        then
            descendant:Destroy()
        end
    end
    applyPreviewSkin(model, skinId)
    model.Parent = parent
    return model
end

local function frameWeapon(viewport, model)
    local camera = Instance.new("Camera")
    camera.FieldOfView = 45
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local cf, size = model:GetBoundingBox()
    local distance = WeaponPreview.distance(size.X / 2, size.Y / 2, size.Z / 2, 1.5, camera.FieldOfView)
    camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(distance, distance * 0.2, distance), cf.Position)
    return camera, cf.Position, distance
end

function LoadoutController:BuildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "LoadoutGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.35
    dim.Parent = gui

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.46)
    panel.Size = UDim2.fromScale(0.92, 0.82)
    panel.BackgroundColor3 = PANEL
    panel.Parent = dim
    corner(panel, 16)
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(1180, 760)
    constraint.Parent = panel
    self.Panel = panel

    local title = label(panel, "LOADOUT", 30, ACCENT, Enum.Font.GothamBlack)
    title.Position = UDim2.fromOffset(22, 12)
    title.Size = UDim2.new(0.48, 0, 0, 40)
    self.Title = title

    local status = label(panel, "", 14, MUTED, Enum.Font.GothamMedium)
    status.AnchorPoint = Vector2.new(1, 0)
    status.Position = UDim2.new(1, -78, 0, 18)
    status.Size = UDim2.new(0.42, 0, 0, 30)
    status.TextXAlignment = Enum.TextXAlignment.Right
    self.StatusLabel = status

    local close = button(panel, "X", PANEL_LIGHT)
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -16, 0, 12)
    close.Size = UDim2.fromOffset(44, 44)
    close.TextSize = 20
    close.Activated:Connect(function()
        self:Close()
    end)
    self.CloseButton = close

    local strip = Instance.new("ScrollingFrame")
    strip.Position = UDim2.new(0, 22, 0, 62)
    strip.Size = UDim2.new(1, -44, 0, 72)
    strip.BackgroundTransparency = 1
    strip.ScrollBarThickness = 3
    strip.ScrollingDirection = Enum.ScrollingDirection.X
    strip.AutomaticCanvasSize = Enum.AutomaticSize.X
    strip.CanvasSize = UDim2.new()
    strip.Parent = panel
    local stripLayout = Instance.new("UIListLayout")
    stripLayout.FillDirection = Enum.FillDirection.Horizontal
    stripLayout.Padding = UDim.new(0, 8)
    stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
    stripLayout.Parent = strip
    self.CategoryStrip = strip

    local subStrip = Instance.new("ScrollingFrame")
    subStrip.Position = UDim2.new(0, 22, 0, 136)
    subStrip.Size = UDim2.new(1, -44, 0, 42)
    subStrip.BackgroundTransparency = 1
    subStrip.ScrollBarThickness = 2
    subStrip.ScrollingDirection = Enum.ScrollingDirection.X
    subStrip.AutomaticCanvasSize = Enum.AutomaticSize.X
    subStrip.CanvasSize = UDim2.new()
    subStrip.Visible = false
    subStrip.Parent = panel
    local subLayout = Instance.new("UIListLayout")
    subLayout.FillDirection = Enum.FillDirection.Horizontal
    subLayout.Padding = UDim.new(0, 8)
    subLayout.SortOrder = Enum.SortOrder.LayoutOrder
    subLayout.Parent = subStrip
    self.SubStrip = subStrip

    local body = Instance.new("Frame")
    body.Position = UDim2.new(0, 22, 0, 144)
    body.Size = UDim2.new(1, -44, 1, -166)
    body.BackgroundTransparency = 1
    body.Parent = panel
    self.Body = body

    local browser = Instance.new("ScrollingFrame")
    browser.Size = UDim2.new(0.6, -8, 1, 0)
    browser.BackgroundTransparency = 1
    browser.ScrollBarThickness = 5
    browser.AutomaticCanvasSize = Enum.AutomaticSize.Y
    browser.CanvasSize = UDim2.new()
    browser.Parent = body
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(170, 154)
    grid.CellPadding = UDim2.fromOffset(10, 10)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = browser
    self.Browser = browser
    self.CardGrid = grid

    local preview = Instance.new("Frame")
    preview.AnchorPoint = Vector2.new(1, 0)
    preview.Position = UDim2.fromScale(1, 0)
    preview.Size = UDim2.new(0.4, -8, 1, 0)
    preview.BackgroundColor3 = PANEL_LIGHT
    preview.Parent = body
    corner(preview, 14)
    self.PreviewPanel = preview

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1, 0, 0.49, 0)
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.fromRGB(190, 195, 210)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -0.5)
    viewport.Parent = preview
    self.Viewport = viewport

    local glyph = label(viewport, "", 30, ACCENT, Enum.Font.GothamBlack)
    glyph.Size = UDim2.fromScale(1, 1)
    glyph.TextXAlignment = Enum.TextXAlignment.Center
    glyph.TextYAlignment = Enum.TextYAlignment.Center
    glyph.Visible = false
    self.PreviewGlyph = glyph

    local name = label(preview, "SELECT AN ITEM", 25, TEXT, Enum.Font.GothamBlack)
    name.Position = UDim2.new(0, 18, 0.49, 0)
    name.Size = UDim2.new(1, -36, 0, 34)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    self.NameLabel = name

    local details = label(preview, "", 16, MUTED, Enum.Font.GothamMedium)
    details.Position = UDim2.new(0, 18, 0.49, 38)
    details.Size = UDim2.new(1, -36, 0.26, 0)
    details.TextWrapped = true
    details.TextYAlignment = Enum.TextYAlignment.Top
    self.DetailLabel = details

    local equip = button(preview, "SELECT ITEM", ACCENT)
    equip.AnchorPoint = Vector2.new(0, 1)
    equip.Position = UDim2.new(0, 18, 1, -16)
    equip.Size = UDim2.new(1, -36, 0, 50)
    equip.TextColor3 = PANEL
    equip.TextSize = 20
    equip.Activated:Connect(function()
        self:EquipActive()
    end)
    self.EquipButton = equip

    self:ApplyResponsiveLayout()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        self:ApplyResponsiveLayout()
    end)
end

function LoadoutController:ApplyResponsiveLayout()
    local width = workspace.CurrentCamera.ViewportSize.X
    if width < 760 then
        self.Panel.Size = UDim2.fromScale(0.96, 0.9)
        self.Browser.Size = UDim2.new(1, 0, 0.54, -5)
        self.PreviewPanel.AnchorPoint = Vector2.new(0, 1)
        self.PreviewPanel.Position = UDim2.fromScale(0, 1)
        self.PreviewPanel.Size = UDim2.new(1, 0, 0.46, -5)
        self.CardGrid.CellSize = UDim2.fromOffset(145, 126)
    else
        self.Panel.Size = UDim2.fromScale(0.92, 0.82)
        self.Browser.Size = UDim2.new(0.6, -8, 1, 0)
        self.PreviewPanel.AnchorPoint = Vector2.new(1, 0)
        self.PreviewPanel.Position = UDim2.fromScale(1, 0)
        self.PreviewPanel.Size = UDim2.new(0.4, -8, 1, 0)
        self.CardGrid.CellSize = UDim2.fromOffset(170, 154)
    end
end

function LoadoutController:SetPreviewWeapon(weaponName, skinId)
    for _, child in self.Viewport:GetChildren() do
        if not child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    self.PreviewModel = nil
    self.PreviewGlyph.Visible = false
    local model = cloneWeaponModel(weaponName, self.Viewport, skinId)
    if not model then
        self.PreviewGlyph.Text = "NO PREVIEW"
        self.PreviewGlyph.Visible = true
        return
    end
    local camera, center, distance = frameWeapon(self.Viewport, model)
    self.PreviewModel = model
    self.PreviewCamera = camera
    self.PreviewCenter = center
    self.PreviewDistance = distance
end

function LoadoutController:SetTextPreview(glyph)
    for _, child in self.Viewport:GetChildren() do
        if not child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    self.PreviewModel = nil
    self.PreviewGlyph.Text = glyph
    self.PreviewGlyph.Visible = true
end

function LoadoutController:ShowActivePreview()
    local category = self.ActiveCategory
    local id = self.ActiveItem
    self.ActiveLocked = false
    if not id then
        self.NameLabel.Text = "SELECT AN ITEM"
        self.DetailLabel.Text = "Choose a card to preview it."
        self:SetTextPreview("PREVIEW")
        self:RefreshEquipButton()
        return
    end

    if table.find(Weapons.SLOTS, category) then
        if id == NONE then
            self.NameLabel.Text = "NONE"
            self.DetailLabel.Text = "Leave this optional slot empty."
            self:SetTextPreview("EMPTY SLOT")
        else
            self.NameLabel.Text = pretty(id)
            self.DetailLabel.Text = table.concat(statLines(Weapons[id]), "\n")
            self:SetPreviewWeapon(id)
        end
    elseif category == "AlterEgo" then
        local ego = AlterEgos.get(id)
        self.NameLabel.Text = ego and ego.Name:upper() or pretty(id)
        self.DetailLabel.Text = ego and (ego.Tagline .. "\nMutates into " .. ego.Mutant) or ""
        self:SetTextPreview(ego and ego.Mutant:upper() or "ALTER EGO")
    elseif category == "Celebration" then
        local celebration = Celebrations.get(id)
        self.NameLabel.Text = celebration and celebration.Name:upper() or pretty(id)
        self.DetailLabel.Text = celebration
                and (("%s  |  %ss  |  Flashing: %s\n%s"):format(
                    celebration.Tier,
                    celebration.Length,
                    celebration.Flashing,
                    celebration.Concept
                ))
            or ""
        self:SetTextPreview(CELEBRATION_GLYPHS[id] or "CELEBRATE")
    elseif category == "Skins" then
        if not self.ActiveSkinWeapon then
            self.NameLabel.Text = "NO WEAPON SELECTED"
            self.DetailLabel.Text = "Equip a weapon before choosing its skin."
            self:SetTextPreview("SKINS")
            self.ActiveItem = nil
            self:RefreshEquipButton()
            return
        end
        self.NameLabel.Text = id == DEFAULT_SKIN and "DEFAULT" or pretty(id)
        local selected
        for _, item in self.SkinOptions[self.ActiveSkinWeapon] or {} do
            if item.Id == id then
                selected = item
                break
            end
        end
        self.ActiveLocked = selected and not selected.Ready or false
        self.DetailLabel.Text = self.ActiveLocked
                and "Previewable draft. Unlock requirement: asset setup must be completed."
            or (selected and selected.Concept or "Original weapon appearance.")
        self:SetPreviewWeapon(self.ActiveSkinWeapon, id ~= DEFAULT_SKIN and id or nil)
    end
    self:RefreshEquipButton()
end

function LoadoutController:IsEquipped(category, id)
    if table.find(Weapons.SLOTS, category) then
        local equipped = self.Equipped[category]
        return (id == NONE and equipped == nil) or equipped == id
    end
    if category == "AlterEgo" then
        return self.Equipped.AlterEgo == id
    end
    if category == "Celebration" then
        return self.Favorites[1] == id
    end
    if category == "Skins" then
        local equipped = self.EquippedSkins[self.ActiveSkinWeapon]
        return (id == DEFAULT_SKIN and equipped == nil) or equipped == id
    end
    return false
end

function LoadoutController:RefreshEquipButton()
    if not self.ActiveItem then
        self.EquipButton.Text = "SELECT ITEM"
        self.EquipButton.BackgroundColor3 = PANEL_SELECTED
        self.EquipButton.TextColor3 = MUTED
        self.EquipButton.Active = false
    elseif self.ActiveLocked then
        self.EquipButton.Text = "LOCKED — VIEW ONLY"
        self.EquipButton.BackgroundColor3 = PANEL_SELECTED
        self.EquipButton.TextColor3 = MUTED
        self.EquipButton.Active = false
    elseif self:IsEquipped(self.ActiveCategory, self.ActiveItem) then
        self.EquipButton.Text = "EQUIPPED"
        self.EquipButton.BackgroundColor3 = PANEL_SELECTED
        self.EquipButton.TextColor3 = ACCENT
        self.EquipButton.Active = false
    else
        self.EquipButton.Text = "EQUIP NOW"
        self.EquipButton.BackgroundColor3 = ACCENT
        self.EquipButton.TextColor3 = PANEL
        self.EquipButton.Active = true
    end
end

function LoadoutController:MakeCard(item, order)
    local equipped = self:IsEquipped(self.ActiveCategory, item.Id)
    local selected = self.ActiveItem == item.Id
    local card = button(self.Browser, "", selected and PANEL_SELECTED or PANEL_LIGHT)
    card.LayoutOrder = order
    card.Text = ""
    local cardOutline =
        outline(card, selected and (SLOT_COLORS[self.ActiveCategory] or ACCENT) or PANEL_LIGHT, selected and 3 or 1)

    local visual = Instance.new("Frame")
    visual.Position = UDim2.fromOffset(8, 8)
    visual.Size = UDim2.new(1, -16, 0.61, 0)
    visual.BackgroundColor3 = PANEL
    visual.Parent = card
    corner(visual, 8)

    if item.WeaponModel then
        local viewport = Instance.new("ViewportFrame")
        viewport.Size = UDim2.fromScale(1, 1)
        viewport.BackgroundTransparency = 1
        viewport.Ambient = Color3.fromRGB(185, 190, 205)
        viewport.LightColor = Color3.fromRGB(255, 255, 255)
        viewport.Parent = visual
        local model = cloneWeaponModel(item.WeaponModel, viewport, item.SkinId)
        if model then
            frameWeapon(viewport, model)
        end
    else
        local glyph = label(visual, item.Glyph or "", 18, item.Color or ACCENT, Enum.Font.GothamBlack)
        glyph.Size = UDim2.fromScale(1, 1)
        glyph.TextXAlignment = Enum.TextXAlignment.Center
        glyph.TextYAlignment = Enum.TextYAlignment.Center
    end

    local itemName = label(card, item.Name, 15, TEXT, Enum.Font.GothamBold)
    itemName.Position = UDim2.new(0, 9, 0.63, 0)
    itemName.Size = UDim2.new(1, -18, 0, 24)
    itemName.TextTruncate = Enum.TextTruncate.AtEnd

    local stateText = item.Locked and (item.Requirement or "LOCKED") or (equipped and "CHECK  EQUIPPED" or "PREVIEW")
    local stateColor = item.Locked and MUTED or (equipped and ACCENT or MUTED)
    local state = label(card, stateText, 12, stateColor, Enum.Font.GothamBold)
    state.Position = UDim2.new(0, 9, 1, -27)
    state.Size = UDim2.new(1, -18, 0, 18)
    state.TextTruncate = Enum.TextTruncate.AtEnd

    card.Activated:Connect(function()
        self.ActiveItem = item.Id
        self.ActiveLocked = item.Locked == true
        self:RenderCards()
        self:ShowActivePreview()
        if self.ActiveCategory == "Celebration" and not Players.LocalPlayer:GetAttribute("InMatch") then
            Knit.GetController("CelebrationController"):Preview(item.Id)
        end
    end)
    if not self.FirstCard then
        self.FirstCard = card
    end
    return cardOutline
end

function LoadoutController:RenderCards()
    clearGuiObjects(self.Browser)
    self.FirstCard = nil
    local items = {}
    local category = self.ActiveCategory

    if table.find(Weapons.SLOTS, category) then
        if category == "Melee" or category == "Utility" then
            table.insert(items, { Id = NONE, Name = "NONE", Glyph = "EMPTY", Color = MUTED })
        end
        for _, id in self.Options[category] or {} do
            table.insert(items, { Id = id, Name = pretty(id), WeaponModel = id })
        end
    elseif category == "AlterEgo" then
        local ids = {}
        for id in AlterEgos.List do
            table.insert(ids, id)
        end
        table.sort(ids)
        for _, id in ids do
            local ego = AlterEgos.get(id)
            table.insert(items, { Id = id, Name = ego.Name:upper(), Glyph = ego.Mutant:upper(), Color = ego.Color })
        end
    elseif category == "Celebration" then
        for _, celebration in Celebrations.all() do
            table.insert(items, {
                Id = celebration.Id,
                Name = celebration.Name:upper(),
                Glyph = CELEBRATION_GLYPHS[celebration.Id] or celebration.Tier:upper(),
                Color = TIER_COLORS[celebration.Tier] or ACCENT,
            })
        end
    elseif category == "Skins" then
        if not self.ActiveSkinWeapon then
            self:RefreshEquipButton()
            return
        end
        table.insert(items, {
            Id = DEFAULT_SKIN,
            Name = "DEFAULT",
            WeaponModel = self.ActiveSkinWeapon,
        })
        for _, skin in self.SkinOptions[self.ActiveSkinWeapon] or {} do
            table.insert(items, {
                Id = skin.Id,
                Name = pretty(skin.Id:match("_([a-z0-9]+)$") or skin.Id),
                WeaponModel = self.ActiveSkinWeapon,
                SkinId = skin.Id,
                Color = TIER_COLORS[skin.Tier] or MUTED,
                Locked = not skin.Ready,
                Requirement = not skin.Ready and "COMING SOON" or nil,
            })
        end
    end

    for index, item in items do
        self:MakeCard(item, index)
    end
    if #items == 0 then
        local empty =
            label(self.Browser, "No items are available for this category yet.", 16, MUTED, Enum.Font.GothamMedium)
        empty.Size = UDim2.new(1, -20, 0, 50)
    end
end

function LoadoutController:RenderSkinWeapons()
    clearGuiObjects(self.SubStrip)
    local candidates = {}
    for _, slot in Weapons.SLOTS do
        local weapon = self.Equipped[slot]
        if weapon then
            table.insert(candidates, weapon)
        end
    end
    if not self.ActiveSkinWeapon or not table.find(candidates, self.ActiveSkinWeapon) then
        self.ActiveSkinWeapon = candidates[1]
    end
    for index, weapon in candidates do
        local selected = self.ActiveSkinWeapon == weapon
        local choice = button(self.SubStrip, pretty(weapon), selected and PANEL_SELECTED or PANEL_LIGHT)
        choice.Size = UDim2.fromOffset(150, 36)
        choice.LayoutOrder = index
        if selected then
            outline(choice, SLOT_COLORS[Weapons[weapon].Slot] or ACCENT, 2)
        end
        choice.Activated:Connect(function()
            self.ActiveSkinWeapon = weapon
            self.ActiveItem = self.EquippedSkins[weapon] or DEFAULT_SKIN
            self:RenderSkinWeapons()
            self:LoadSkins(weapon)
        end)
    end
end

function LoadoutController:LoadSkins(weapon)
    if not weapon then
        self:RenderCards()
        return
    end
    Knit.GetService("SkinService"):GetSkins(weapon):andThen(function(list, current)
        self.SkinOptions[weapon] = list
        self.EquippedSkins[weapon] = current
        if self.ActiveCategory == "Skins" and self.ActiveSkinWeapon == weapon then
            self.ActiveItem = current or DEFAULT_SKIN
            self:RenderCards()
            self:ShowActivePreview()
        end
    end)
end

function LoadoutController:SelectCategory(category)
    self.ActiveCategory = category
    self.SubStrip.Visible = category == "Skins"
    self.Body.Position = category == "Skins" and UDim2.new(0, 22, 0, 184) or UDim2.new(0, 22, 0, 144)
    self.Body.Size = category == "Skins" and UDim2.new(1, -44, 1, -206) or UDim2.new(1, -44, 1, -166)

    if table.find(Weapons.SLOTS, category) then
        self.ActiveItem = self.Equipped[category] or ((category == "Melee" or category == "Utility") and NONE or nil)
    elseif category == "AlterEgo" then
        self.ActiveItem = self.Equipped.AlterEgo or AlterEgos.DEFAULT
    elseif category == "Celebration" then
        self.ActiveItem = self.Favorites[1] or Celebrations.DEFAULT_ID
    elseif category == "Skins" then
        self:RenderSkinWeapons()
        self.ActiveItem = self.ActiveSkinWeapon and (self.EquippedSkins[self.ActiveSkinWeapon] or DEFAULT_SKIN) or nil
        self:LoadSkins(self.ActiveSkinWeapon)
    end
    self:Render()
end

function LoadoutController:RenderCategoryStrip()
    clearGuiObjects(self.CategoryStrip)
    local categories = self.Section == "Customize" and CUSTOMIZE_CATEGORIES or LOADOUT_SLOTS
    for index, category in categories do
        local selected = category == self.ActiveCategory
        local equippedText = ""
        if self.Section == "Loadout" then
            local value = category == "AlterEgo" and self.Equipped.AlterEgo or self.Equipped[category]
            equippedText = "\n" .. pretty(value)
        end
        local categoryButton =
            button(self.CategoryStrip, category:upper() .. equippedText, selected and PANEL_SELECTED or PANEL_LIGHT)
        categoryButton.Size = UDim2.fromOffset(self.Section == "Customize" and 190 or 175, 66)
        categoryButton.LayoutOrder = index
        categoryButton.TextSize = 14
        categoryButton.TextWrapped = true
        if selected then
            outline(categoryButton, SLOT_COLORS[category] or ACCENT, 3)
        end
        categoryButton.Activated:Connect(function()
            self:SelectCategory(category)
        end)
    end
end

function LoadoutController:Render()
    self.Title.Text = self.Section == "Customize" and "CUSTOMIZE" or "LOADOUT"
    self:RenderCategoryStrip()
    if self.ActiveCategory == "Skins" then
        self:RenderSkinWeapons()
    end
    self:RenderCards()
    self:ShowActivePreview()
end

function LoadoutController:SetStatus(text, isError)
    self.StatusLabel.Text = text
    self.StatusLabel.TextColor3 = isError and RED or MUTED
end

function LoadoutController:EquipActive()
    local category = self.ActiveCategory
    local id = self.ActiveItem
    if not id or self.ActiveLocked or Players.LocalPlayer:GetAttribute("InMatch") then
        return
    end
    self.EquipButton.Active = false
    self.EquipButton.Text = "EQUIPPING..."
    self:SetStatus("Saving immediately...", false)

    local function finish(ok, reason)
        if ok then
            self:SetStatus("Equipped. You can keep browsing or queue now.", false)
            self:Render()
        else
            local message = reason == "match_locked" and "Locked — your match is starting."
                or "That item could not be equipped."
            self:SetStatus(message, true)
            self:RefreshEquipButton()
        end
    end

    if table.find(Weapons.SLOTS, category) then
        Knit.GetService("LoadoutService")
            :SetSlot(category, id == NONE and nil or id)
            :andThen(function(ok, reason, current)
                if ok then
                    for _, slot in Weapons.SLOTS do
                        self.Equipped[slot] = current[slot]
                    end
                end
                finish(ok, reason)
            end)
            :catch(function()
                finish(false, "request_failed")
            end)
    elseif category == "AlterEgo" then
        Knit.GetService("AlterEgoService"):Select(id):andThen(function(ok)
            if ok then
                self.Equipped.AlterEgo = id
            end
            finish(ok, ok and nil or "match_locked")
        end)
    elseif category == "Celebration" then
        local favorites = { id }
        for _, favorite in self.Favorites do
            if favorite ~= id and #favorites < Celebrations.MAX_FAVORITES then
                table.insert(favorites, favorite)
            end
        end
        Knit.GetService("CelebrationService"):SetFavorites(favorites):andThen(function(ok, reason)
            if ok then
                self.Favorites = favorites
            end
            finish(ok, reason)
        end)
    elseif category == "Skins" then
        Knit.GetService("SkinService")
            :SetSkin(self.ActiveSkinWeapon, id == DEFAULT_SKIN and nil or id)
            :andThen(function(ok, reason)
                if ok then
                    self.EquippedSkins[self.ActiveSkinWeapon] = id == DEFAULT_SKIN and nil or id
                end
                finish(ok, reason)
            end)
    end
end

function LoadoutController:Open(section)
    if Players.LocalPlayer:GetAttribute("InMatch") or Players.LocalPlayer:GetAttribute("QueueState") == "Committed" then
        return
    end
    self.Section = section == "Customize" and "Customize" or "Loadout"
    self.ActiveCategory = self.Section == "Customize" and "Celebration" or "Primary"
    self.ActiveItem = nil
    self:SetStatus("Changes save immediately.", false)
    self.Gui.Enabled = true
    self:Render()
    GuiService.SelectedObject = self.CloseButton

    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:UnequipTools()
    end
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    end)
    RunService:BindToRenderStep("LoadoutMouse", Enum.RenderPriority.Last.Value, function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)

    Knit.GetService("LoadoutService"):GetLoadout():andThen(function(current)
        self.Equipped.Primary = current.Primary
        self.Equipped.Secondary = current.Secondary
        self.Equipped.Melee = current.Melee
        self.Equipped.Utility = current.Utility
        if table.find(Weapons.SLOTS, self.ActiveCategory) then
            self.ActiveItem = self.Equipped[self.ActiveCategory]
        end
        if self.Gui.Enabled then
            self:Render()
        end
    end)
    Knit.GetService("AlterEgoService"):Get():andThen(function(id)
        self.Equipped.AlterEgo = id
        if self.ActiveCategory == "AlterEgo" then
            self.ActiveItem = id
        end
        if self.Gui.Enabled then
            self:Render()
        end
    end)
    Knit.GetService("CelebrationService"):GetFavorites():andThen(function(favorites)
        self.Favorites = favorites
        if self.Section == "Customize" and self.ActiveCategory == "Celebration" then
            self.ActiveItem = favorites[1]
        end
        if self.Gui.Enabled then
            self:Render()
        end
    end)
end

function LoadoutController:Close()
    if not self.Gui.Enabled then
        return
    end
    self.Gui.Enabled = false
    self.PreviewModel = nil
    GuiService.SelectedObject = nil
    RunService:UnbindFromRenderStep("LoadoutMouse")
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    end)
end

function LoadoutController:KnitStart()
    self.Section = "Loadout"
    self.ActiveCategory = "Primary"
    self.ActiveItem = nil
    self.ActiveSkinWeapon = nil
    self.Options = { Primary = {}, Secondary = {}, Melee = {}, Utility = {} }
    self.Equipped = { AlterEgo = AlterEgos.DEFAULT }
    self.EquippedSkins = {}
    self.SkinOptions = {}
    self.Favorites = { Celebrations.DEFAULT_ID }
    self:BuildGui()

    Knit.GetService("LoadoutService"):GetOptions():andThen(function(options)
        self.Options = options
        if self.Gui.Enabled then
            self:Render()
        end
    end)

    local angle = 0
    RunService.RenderStepped:Connect(function(delta)
        if not self.Gui.Enabled or not self.PreviewModel or Players.LocalPlayer:GetAttribute("ReducedEffects") then
            return
        end
        angle += delta * 0.65
        local distance = self.PreviewDistance or 8
        local center = self.PreviewCenter
        self.PreviewCamera.CFrame = CFrame.lookAt(
            center + Vector3.new(math.cos(angle) * distance, distance * 0.2, math.sin(angle) * distance),
            center
        )
    end)

    ProximityPromptService.PromptTriggered:Connect(function(prompt)
        if prompt.Name == "WeaponKiosk" then
            self:Open("Loadout")
        end
    end)
    Players.LocalPlayer:GetAttributeChangedSignal("InMatch"):Connect(function()
        if Players.LocalPlayer:GetAttribute("InMatch") then
            self:Close()
        end
    end)
    Players.LocalPlayer:GetAttributeChangedSignal("QueueState"):Connect(function()
        if Players.LocalPlayer:GetAttribute("QueueState") == "Committed" then
            self:Close()
        end
    end)
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not self.Gui.Enabled then
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
            self:Close()
        end
    end)
end

return LoadoutController
