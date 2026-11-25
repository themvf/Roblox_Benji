-- Seed an editable lobby from the current source layout. Run once; later edits
-- belong to the saved .rbxm, not this template.
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3, Enum =
    roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

local Template = {}

local function vec(p)
    return Vector3.new(p[1], p[2], p[3])
end

local function part(parent, name, position, size, color)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = vec(size)
    p.CFrame = CFrame.new(vec(position))
    p.Color = color
    p.Parent = parent
    return p
end

local function folder(parent, name)
    local child = Instance.new("Folder")
    child.Name = name
    child.Parent = parent
    return child
end

local function marker(parent, role, id, position, size, color)
    local p = part(parent, id, position, size, color)
    p:SetAttribute("Role", role)
    p:SetAttribute("Id", id)
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Transparency = 0.45
    p.Material = Enum.Material.Neon
    local gui = Instance.new("BillboardGui")
    gui.Name = "EditorLabel"
    gui.Size = roblox.UDim2.fromScale(math.max(8, size[1]), 3)
    gui.AlwaysOnTop = true
    gui.StudsOffset = Vector3.new(0, math.max(3, size[2] / 2 + 2), 0)
    gui.Parent = p
    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.Size = roblox.UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.TextStrokeTransparency = 0
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Text = role .. "  " .. id
    text.Parent = gui
    return p
end

function Template.create(layout)
    local root = Instance.new("Model")
    root.Name = "Lobby"
    root:SetAttribute("LobbySource", true)
    local geometry = folder(root, "Geometry")
    local authoring = folder(root, "Authoring")
    local o, palette = layout.Origin, layout.Palette
    local function at(p)
        return { o[1] + p[1], o[2] + p[2], o[3] + p[3] }
    end
    local w, d = layout.Size[1], layout.Size[2]
    part(geometry, "Floor", at({ 0, -1, 0 }), { w, 2, d }, palette.Floor)
    for x = -w / 2 + 10, w / 2 - 10, 10 do
        local line = part(geometry, "GridX", at({ x, 0.02, 0 }), { 0.3, 0.04, d }, palette.FloorGrid)
        line.CanCollide = false
    end
    for z = -d / 2 + 10, d / 2 - 10, 10 do
        local line = part(geometry, "GridZ", at({ 0, 0.02, z }), { w, 0.04, 0.3 }, palette.FloorGrid)
        line.CanCollide = false
    end
    local h = 30
    for _, wall in
        {
            { { 0, h / 2, -d / 2 }, { w, h, 1 } },
            { { 0, h / 2, d / 2 }, { w, h, 1 } },
            { { -w / 2, h / 2, 0 }, { 1, h, d } },
            { { w / 2, h / 2, 0 }, { 1, h, d } },
        }
    do
        local rail = part(geometry, "Rail", at(wall[1]), wall[2], palette.Wall)
        rail.Transparency = 1
    end
    for _, spec in layout.Pieces do
        local p = part(geometry, spec.name, at(spec.pos), spec.size, palette[spec.color])
        if spec.rot then
            p.CFrame *= CFrame.Angles(math.rad(spec.rot[1]), math.rad(spec.rot[2]), math.rad(spec.rot[3]))
        end
        if spec.collide == false then
            p.CanCollide = false
            p.CanTouch = false
            p.CanQuery = false
        end
        if spec.color == "Accent" or (spec.color == "Ego" and spec.name:find("Ring")) then
            p.Material = Enum.Material.Neon
        end
    end
    local spawns = folder(authoring, "Spawns")
    for i, pos in layout.Spawns do
        marker(spawns, "Spawn", tostring(i), at(pos), { 3, 0.2, 3 }, palette.Accent)
    end
    local pads = folder(authoring, "QueuePads")
    for _, spec in layout.Pads do
        marker(pads, "QueuePad", spec.name, at(spec.pos), spec.size, spec.color)
    end
    local stations = folder(authoring, "Stations")
    marker(stations, "Board", "Board", at(layout.Board.pos), layout.Board.size, palette.Pillar)
    local kiosk = marker(stations, "Kiosk", "Kiosk", at(layout.Kiosk.pos), layout.Kiosk.size, palette.Armory)
    kiosk:SetAttribute("Showcase", layout.Kiosk.showcase)
    local signs = folder(authoring, "Wayfinding")
    for _, spec in layout.Wayfinding do
        local sign =
            marker(signs, "Wayfinding", spec.name, at(spec.pos), { spec.size[1], spec.size[2], 1 }, palette[spec.color])
        sign:SetAttribute("Title", spec.title)
        sign:SetAttribute("Detail", spec.detail)
    end
    local lights = folder(authoring, "Lights")
    for _, spec in layout.Lights do
        local light = marker(lights, "Light", spec.name, at(spec.pos), { 2, 2, 2 }, palette[spec.color])
        light:SetAttribute("Range", spec.range)
        light:SetAttribute("Brightness", spec.brightness)
    end
    return root
end

return Template
