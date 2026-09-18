-- Weapon kiosk screen: pick a primary and secondary with a big rotating 3D preview.
-- Opens from the kiosk's ProximityPrompt in the lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local LoadoutController = Knit.CreateController({ Name = "LoadoutController" })

local PANEL = Color3.fromRGB(28, 30, 38)
local PANEL_LIGHT = Color3.fromRGB(44, 47, 58)
local ACCENT = Color3.fromRGB(255, 200, 70)
local SLOT_COLORS = {
    Primary = Color3.fromRGB(80, 230, 120),
    Secondary = Color3.fromRGB(80, 150, 255),
    Melee = Color3.fromRGB(255, 120, 90),
    Utility = Color3.fromRGB(200, 120, 255),
    Celebration = Color3.fromRGB(255, 200, 70),
}
local SLOTS = { "Primary", "Secondary", "Melee", "Utility", "Celebration" }
local Celebrations = require(ReplicatedStorage.Shared.Celebrations)
local TEXT = Color3.fromRGB(245, 245, 250)
local MUTED = Color3.fromRGB(160, 165, 180)
local TIER_COLORS = {
    Common = Color3.fromRGB(170, 175, 185),
    Rare = Color3.fromRGB(80, 150, 255),
    Legendary = Color3.fromRGB(255, 160, 60),
    Mythical = Color3.fromRGB(230, 80, 255),
}

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = inst
end

local function label(parent, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size
    l.TextColor3 = color or TEXT
    l.Font = font or Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 0, size + 6)
    l.Parent = parent
    return l
end

-- Short human stat summary from the Rivals stats table
local function statLines(stats)
    if stats.Type == "Melee" then
        return {
            ("Damage  %s"):format(stats.Damage[1]),
            ("Reach  %s studs"):format(stats.Range),
            ("Arc  %s deg"):format(stats.Arc),
            ("Swing  %.2fs"):format(stats.Cooldown),
            "Ammo  None",
            ("Equip  %.2fs"):format(stats.EquipTime),
        }
    end
    local dmg = stats.Damage[1]
    local shotDmg = dmg * stats.Pellets
    local dps = shotDmg / stats.Cooldown
    if stats.Burst then
        dps = (shotDmg * stats.Burst) / stats.Cooldown
    end
    local mag = stats.Ammo[1] == math.huge and "Infinite" or tostring(stats.Ammo[1])
    local mode = stats.Burst and ("Burst x" .. stats.Burst) or (stats.Auto and "Automatic" or "Semi-auto")
    return {
        ("Damage  %s%s"):format(dmg, stats.Pellets > 1 and (" x" .. stats.Pellets) or ""),
        ("Headshot  %s"):format(stats.Crit[1] * stats.Pellets),
        ("DPS  %d"):format(dps),
        ("Fire  %s"):format(mode),
        ("Mag  %s"):format(mag),
        ("Reload  %.2fs"):format(stats.Reload),
    }
end

function LoadoutController:BuildGui()
    local player = Players.LocalPlayer
    local gui = Instance.new("ScreenGui")
    gui.Name = "LoadoutGui"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10
    gui.Parent = player:WaitForChild("PlayerGui")
    self.Gui = gui

    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.45
    dim.Parent = gui

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0.8, 0, 0.8, 0)
    panel.BackgroundColor3 = PANEL
    panel.Parent = dim
    corner(panel, 16)

    local title = label(panel, "WEAPONS", 34, ACCENT, Enum.Font.GothamBlack)
    title.Position = UDim2.new(0, 24, 0, 14)
    title.Size = UDim2.new(0.5, 0, 0, 40)

    local close = Instance.new("TextButton")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -16, 0, 14)
    close.Size = UDim2.fromOffset(44, 44)
    close.BackgroundColor3 = PANEL_LIGHT
    close.Text = "X"
    close.TextSize = 22
    close.Font = Enum.Font.GothamBlack
    close.TextColor3 = TEXT
    close.Parent = panel
    corner(close, 10)
    close.Activated:Connect(function()
        self:Close()
    end)

    -- Left: two columns of weapon buttons
    local lists = Instance.new("Frame")
    lists.Position = UDim2.new(0, 24, 0, 70)
    lists.Size = UDim2.new(0.54, 0, 1, -140)
    lists.BackgroundTransparency = 1
    lists.Parent = panel

    self.Columns = {}
    for i, slot in SLOTS do
        local col = Instance.new("ScrollingFrame")
        col.Position = UDim2.new((i - 1) * 0.204, 0, 0, 0)
        col.Size = UDim2.new(0.19, 0, 1, 0)
        col.BackgroundTransparency = 1
        col.ScrollBarThickness = 4
        col.AutomaticCanvasSize = Enum.AutomaticSize.Y
        col.CanvasSize = UDim2.new()
        col.Parent = lists
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.Parent = col
        local head = label(col, slot:upper(), 16, SLOT_COLORS[slot], Enum.Font.GothamBlack)
        head.LayoutOrder = 0
        self.Columns[slot] = col
    end

    -- Right: 3D preview + stats
    local preview = Instance.new("Frame")
    preview.AnchorPoint = Vector2.new(1, 0)
    preview.Position = UDim2.new(1, -24, 0, 70)
    preview.Size = UDim2.new(0.40, 0, 1, -140)
    preview.BackgroundColor3 = PANEL_LIGHT
    preview.Parent = panel
    corner(preview, 14)

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1, 0, 0.62, 0)
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.fromRGB(200, 200, 210)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -0.5)
    viewport.Parent = preview
    self.Viewport = viewport
    local cam = Instance.new("Camera")
    cam.Parent = viewport
    viewport.CurrentCamera = cam
    self.PreviewCamera = cam

    local name = label(preview, "", 30, TEXT, Enum.Font.GothamBlack)
    name.Position = UDim2.new(0, 20, 0.62, 0)
    name.Size = UDim2.new(1, -40, 0, 40)
    self.NameLabel = name

    local stats = Instance.new("Frame")
    stats.Position = UDim2.new(0, 20, 0.62, 44)
    stats.Size = UDim2.new(1, -40, 0.38, -110)
    stats.BackgroundTransparency = 1
    stats.Parent = preview
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.5, -6, 0, 26)
    grid.CellPadding = UDim2.fromOffset(6, 4)
    grid.Parent = stats
    self.StatLabels = {}
    for i = 1, 6 do
        local l = label(stats, "", 18, MUTED, Enum.Font.GothamMedium)
        l.LayoutOrder = i
        self.StatLabels[i] = l
    end

    -- Skins for the previewed weapon: one chip per skin, plus Default
    local skinRow = Instance.new("ScrollingFrame")
    skinRow.AnchorPoint = Vector2.new(0, 1)
    skinRow.Position = UDim2.new(0, 20, 1, -12)
    skinRow.Size = UDim2.new(1, -40, 0, 48)
    skinRow.BackgroundTransparency = 1
    skinRow.ScrollBarThickness = 3
    skinRow.ScrollingDirection = Enum.ScrollingDirection.X
    skinRow.AutomaticCanvasSize = Enum.AutomaticSize.X
    skinRow.CanvasSize = UDim2.new()
    skinRow.Parent = preview
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.Padding = UDim.new(0, 8)
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Parent = skinRow
    self.SkinRow = skinRow

    -- Bottom: current loadout + confirm
    local bar = Instance.new("Frame")
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.Position = UDim2.new(0, 24, 1, -16)
    bar.Size = UDim2.new(1, -48, 0, 50)
    bar.BackgroundTransparency = 1
    bar.Parent = panel

    self.SummaryLabel = label(bar, "", 20, MUTED, Enum.Font.GothamMedium)
    self.SummaryLabel.Size = UDim2.new(0.6, 0, 1, 0)
    self.SummaryLabel.TextYAlignment = Enum.TextYAlignment.Center

    local confirm = Instance.new("TextButton")
    confirm.AnchorPoint = Vector2.new(1, 0)
    confirm.Position = UDim2.new(1, 0, 0, 0)
    confirm.Size = UDim2.new(0.3, 0, 1, 0)
    confirm.BackgroundColor3 = ACCENT
    confirm.Text = "EQUIP"
    confirm.TextSize = 24
    confirm.Font = Enum.Font.GothamBlack
    confirm.TextColor3 = PANEL
    confirm.Parent = bar
    corner(confirm, 12)
    confirm.Activated:Connect(function()
        self:Confirm()
    end)
    self.ConfirmButton = confirm
end

function LoadoutController:MakeButton(slot, weaponName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 46)
    btn.BackgroundColor3 = PANEL_LIGHT
    btn.Text = "  " .. weaponName:gsub("(%l)(%u)", "%1 %2")
    btn.TextSize = 16
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = TEXT
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = self.Columns[slot]
    corner(btn, 10)
    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 6, 1, 0)
    stripe.BackgroundColor3 = SLOT_COLORS[slot]
    stripe.BorderSizePixel = 0
    stripe.Visible = false
    stripe.Parent = btn
    corner(stripe, 6)
    btn.Activated:Connect(function()
        if slot == "Celebration" then
            local favs = self.Favorites
            local idx = table.find(favs, weaponName)
            if idx then
                table.remove(favs, idx)
            elseif #favs < Celebrations.MAX_FAVORITES then
                table.insert(favs, weaponName)
            end
            self:Refresh()
            self:PreviewCelebration(weaponName)
            return
        end
        local optional = slot == "Melee" or slot == "Utility"
        if optional and self.Selected[slot] == weaponName then
            self.Selected[slot] = nil -- tap again to leave the slot empty
        else
            self.Selected[slot] = weaponName
        end
        self:Refresh()
        self:Preview(weaponName)
    end)
    self.Buttons[slot][weaponName] = { Button = btn, Stripe = stripe }
end

function LoadoutController:Refresh()
    for slot, set in self.Buttons do
        for name, ui in set do
            local on
            if slot == "Celebration" then
                local idx = table.find(self.Favorites, name)
                on = idx ~= nil
                local cel = Celebrations.get(name)
                ui.Button.Text = "  " .. (idx and (idx .. ". ") or "") .. (cel and cel.Name or name)
            else
                on = self.Selected[slot] == name
            end
            ui.Stripe.Visible = on
            ui.Button.BackgroundColor3 = on and Color3.fromRGB(62, 66, 82) or PANEL_LIGHT
        end
    end
    local parts = {}
    for _, slot in SLOTS do
        if slot == "Celebration" then
            table.insert(
                parts,
                "Celebration: " .. (self.Favorites[1] and (Celebrations.get(self.Favorites[1]) or {}).Name or "-")
            )
        else
            table.insert(parts, slot .. ": " .. (self.Selected[slot] or "-"))
        end
    end
    self.SummaryLabel.Text = table.concat(parts, "   ")
end

function LoadoutController:Preview(weaponName)
    local viewport = self.Viewport
    for _, c in viewport:GetChildren() do
        if not c:IsA("Camera") then
            c:Destroy()
        end
    end
    local tool = ReplicatedStorage.WeaponTools:FindFirstChild(weaponName)
    local source = tool and tool:FindFirstChildOfClass("Model")
    if not source then
        return
    end
    local model = source:Clone()
    for _, d in model:GetDescendants() do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("Beam") then
            d:Destroy()
        end
    end
    model.Parent = viewport
    local cf, size = model:GetBoundingBox()
    self.PreviewModel = model
    self.PreviewCenter = cf.Position
    self.PreviewRadius = math.max(size.X, size.Y, size.Z)
    self.PreviewPivot = cf

    self.NameLabel.Text = weaponName:gsub("(%l)(%u)", "%1 %2"):upper()
    self.PreviewWeapon = weaponName
    self:ShowSkins(weaponName)
    local stats = Weapons[weaponName]
    local lines = stats and statLines(stats) or {}
    for i, l in self.StatLabels do
        l.Text = lines[i] or ""
    end
end

local function prettyId(id)
    -- skn_uzi_common_cobalt -> Cobalt
    local word = id:match("_([a-z0-9]+)$") or id
    return word:sub(1, 1):upper() .. word:sub(2)
end

function LoadoutController:ShowSkins(weaponName)
    local row = self.SkinRow
    for _, c in row:GetChildren() do
        if c:IsA("TextButton") then
            c:Destroy()
        end
    end
    Knit.GetService("SkinService"):GetSkins(weaponName):andThen(function(list, current)
        if self.PreviewWeapon ~= weaponName then
            return
        end
        local function chip(text, color, skinId, order)
            local b = Instance.new("TextButton")
            b.Size = UDim2.fromOffset(math.max(96, #text * 11 + 24), 40)
            b.BackgroundColor3 = (current == skinId) and color or PANEL
            b.Text = text
            b.TextSize = 16
            b.Font = Enum.Font.GothamBold
            b.TextColor3 = (current == skinId) and PANEL or color
            b.AutoButtonColor = false
            b.LayoutOrder = order
            b.Parent = row
            corner(b, 10)
            local stroke = Instance.new("UIStroke")
            stroke.Color = color
            stroke.Thickness = 2
            stroke.Parent = b
            b.Activated:Connect(function()
                Knit.GetService("SkinService"):SetSkin(weaponName, skinId):andThen(function(ok)
                    if ok then
                        self:ShowSkins(weaponName)
                    end
                end)
            end)
        end
        chip("Default", MUTED, nil, 0)
        for i, sk in list do
            chip(prettyId(sk.Id) .. "  " .. sk.Tier, TIER_COLORS[sk.Tier] or MUTED, sk.Id, i)
        end
    end)
end

function LoadoutController:PreviewCelebration(id)
    local cel = Celebrations.get(id)
    if not cel then
        return
    end
    for _, c in self.Viewport:GetChildren() do
        if not c:IsA("Camera") then
            c:Destroy()
        end
    end
    self.PreviewModel = nil
    self.PreviewWeapon = nil
    for _, c in self.SkinRow:GetChildren() do
        if c:IsA("TextButton") then
            c:Destroy()
        end
    end
    self.NameLabel.Text = cel.Name:upper()
    local lines = {
        "Tier  " .. cel.Tier,
        ("Length  %ss"):format(cel.Length),
        "Flashing  " .. cel.Flashing,
        "Systems  " .. tostring(#(function()
            local t = {}
            for k in cel.Systems do
                table.insert(t, k)
            end
            return t
        end)()),
        cel.Concept,
        "Default = first favourite. Up to 3.",
    }
    for i, l in self.StatLabels do
        l.Text = lines[i] or ""
    end
end

function LoadoutController:Confirm()
    local sel = self.Selected
    if not sel.Primary or not sel.Secondary then
        return
    end
    self.ConfirmButton.Text = "..."
    Knit.GetService("LoadoutService")
        :SetLoadout({
            Primary = sel.Primary,
            Secondary = sel.Secondary,
            Melee = sel.Melee,
            Utility = sel.Utility,
        })
        :andThen(function(result)
            Knit.GetService("CelebrationService"):SetFavorites(self.Favorites)
            self.ConfirmButton.Text = result and "EQUIPPED" or "INVALID"
            task.delay(0.8, function()
                self.ConfirmButton.Text = "EQUIP"
                if result then
                    self:Close()
                end
            end)
        end)
end

function LoadoutController:Open()
    if self.Gui.Enabled then
        return
    end
    local LoadoutService = Knit.GetService("LoadoutService")
    Knit.GetService("CelebrationService"):GetFavorites():andThen(function(favs)
        self.Favorites = favs
        self:Refresh()
    end)
    LoadoutService:GetLoadout():andThen(function(current)
        self.Selected = {
            Primary = current.Primary,
            Secondary = current.Secondary,
            Melee = current.Melee,
            Utility = current.Utility,
        }
        self:Refresh()
        self:Preview(current.Primary)
        self.Gui.Enabled = true
        -- The Weapons Kit re-locks the cursor every frame while a gun is held. Put it away
        -- and force the cursor free after the camera step, for as long as the kiosk is open.
        local character = Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:UnequipTools()
        end
        RunService:BindToRenderStep("KioskMouse", Enum.RenderPriority.Last.Value, function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
    end)
end

function LoadoutController:Close()
    self.Gui.Enabled = false
    RunService:UnbindFromRenderStep("KioskMouse")
end

function LoadoutController:KnitStart()
    self.Selected = {}
    self.Favorites = {}
    self.Buttons = { Primary = {}, Secondary = {}, Melee = {}, Utility = {}, Celebration = {} }
    self:BuildGui()

    Knit.GetService("LoadoutService"):GetOptions():andThen(function(options)
        options.Celebration = {}
        for _, c in Celebrations.all() do
            table.insert(options.Celebration, c.Id)
        end
        for _, slot in SLOTS do
            if #options[slot] == 0 then
                local none = label(self.Columns[slot], "Coming soon", 14, MUTED, Enum.Font.GothamMedium)
                none.LayoutOrder = 1
            end
            for i, name in options[slot] do
                self:MakeButton(slot, name)
                self.Buttons[slot][name].Button.LayoutOrder = i
            end
        end
    end)

    -- Spin the preview
    local angle = 0
    RunService.RenderStepped:Connect(function(dt)
        if not self.Gui.Enabled or not self.PreviewModel then
            return
        end
        angle += dt * 0.8
        local r = self.PreviewRadius * 1.15
        local center = self.PreviewCenter
        local eye = center + Vector3.new(math.cos(angle) * r, r * 0.35, math.sin(angle) * r)
        self.PreviewCamera.CFrame = CFrame.lookAt(eye, center)
    end)

    ProximityPromptService.PromptTriggered:Connect(function(prompt)
        if prompt.Name == "WeaponKiosk" then
            self:Open()
        end
    end)
end

return LoadoutController
