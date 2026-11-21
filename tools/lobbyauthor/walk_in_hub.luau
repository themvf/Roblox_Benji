-- SUPERSEDED (2026-11-20) by faction_islands.luau. Maps/Lobby.lua now holds the Faction Islands
-- marker positions, so this script no longer matches it; kept for the record.
--
-- Build the approved walk-in hub (docs/design/lobby-experience/hub-concept) into the
-- editable lobby source. Run from the project root:
--
--   python docs/design/lobby-experience/hub-concept/export_parts.py
--   lune run tools/lobbyauthor/walk_in_hub.luau
--   lune run tools/lobby.luau convert
--
-- The concept's blockout parts become Geometry. Things the game already draws from
-- markers (queue pads, signs, leaderboard, kiosk, spawns, lights) are skipped and their
-- markers moved to the positions in src/shared/Maps/Lobby.lua instead. The lobby's own
-- stone columns, purple columns and canister are kept and moved into the layout.
-- Replaces Geometry wholesale, so Studio edits made since the last run are lost; the
-- first run backs up the previous source under .mapbuild/lobby-walk-in-hub/.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

Color3 = roblox.Color3
Vector3 = roblox.Vector3
Enum = roblox.Enum
local CFrame = roblox.CFrame
local Instance = roblox.Instance

local Reader = require("../../src/shared/LobbyAuthoring")
local base = require("../../src/shared/Maps/Lobby")

local source = "assets/environment/source/Lobby.rbxm"
local design = "docs/design/lobby-experience/hub-concept/hub_parts.json"
local backupDir = ".mapbuild/lobby-walk-in-hub"
local backup = backupDir .. "/Lobby-before-hub.rbxm"

-- Floor: covers the whole hub (x +-203, z -259..185) with a margin. Small enough that
-- check_lobby_authoring's 200-stud pad move still lands off it.
local FLOOR_SIZE = { 430, 460 }
local FLOOR_CENTRE_Z = -35
local RAIL_HEIGHT = 30

-- Columns and canister the lobby already has: where each goes, in lobby coordinates.
local STONE_SPOTS = { { -36.4, -226.8 }, { 36.4, -226.8 } } -- behind the gate
local PURPLE_SPOTS = {
    -- four around the plaza (bearings 55, 125, 235, 305 at radius 74.2)
    { 60.8, -42.6 },
    { 60.8, 42.6 },
    { -60.8, 42.6 },
    { -60.8, -42.6 },
    -- four outside the avenue walls, seen over them
    { -62, -75 },
    { 62, -75 },
    { -62, -112 },
    { 62, -112 },
}
local CANISTER_SPOT = { -40, 52 } -- left of the shop opening; the leaderboard mirrors it

local bytes = fs.readFile(source)
local root = roblox.deserializeModel(bytes)[1]
assert(root and root:GetAttribute("LobbySource") == true, "expected the editable Lobby model")
local origin = Vector3.new(table.unpack(base.Origin))
local data = serde.decode("json", fs.readFile(design))

local function world(x, y, z)
    return origin + Vector3.new(x, y, z)
end

-- ===== keep the lobby's own models, drop the old hall =====
local geometry = root.Geometry
local columns = assert(geometry:FindFirstChild("Columns"), "Geometry.Columns is missing")
local canisterFolder = assert(geometry:FindFirstChild("Cannister"), "Geometry.Cannister is missing")
for _, child in geometry:GetChildren() do
    if child ~= columns and child ~= canisterFolder then
        child:Destroy()
    end
end

local function centre(model)
    local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            local p, s = part.CFrame.Position, part.Size
            local v, h = { p.X, p.Y, p.Z }, { s.X / 2, s.Y / 2, s.Z / 2 }
            for i = 1, 3 do
                lo[i] = math.min(lo[i], v[i] - h[i])
                hi[i] = math.max(hi[i], v[i] + h[i])
            end
        end
    end
    return Vector3.new((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
end

local function moveTo(model, spot)
    local now = centre(model)
    local delta = world(spot[1], 0, spot[2]) - Vector3.new(now.X, origin.Y, now.Z)
    delta = Vector3.new(delta.X, 0, delta.Z)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.CFrame = part.CFrame + delta
        end
    end
    -- These models store no WorldPivot, so Studio derives the pivot from the moved parts.
end

local function place(folderName, spots)
    local models = columns[folderName]:GetChildren()
    table.sort(models, function(a, b)
        local ca, cb = centre(a), centre(b)
        return ca.X + ca.Z * 1000 < cb.X + cb.Z * 1000
    end)
    assert(#models == #spots, ("%s has %d columns, layout expects %d"):format(folderName, #models, #spots))
    for index, model in models do
        moveTo(model, spots[index])
    end
end
place("Large Stone", STONE_SPOTS)
place("Purple", PURPLE_SPOTS)
moveTo(canisterFolder.BlueContainmentCanister, CANISTER_SPOT)

-- ===== floor and the invisible edge =====
local function part(parent, name, cframe, size, colour, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CFrame = cframe
    p.Size = size
    p.Color = colour or Color3.new(0.5, 0.5, 0.5)
    p.Material = material or Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local floor = part(
    geometry,
    "Floor",
    CFrame.new(world(0, -1, FLOOR_CENTRE_Z)),
    Vector3.new(FLOOR_SIZE[1], 2, FLOOR_SIZE[2]),
    Color3.new(0.07, 0.075, 0.09),
    Enum.Material.Concrete
)
floor.Name = "Floor"

local boundary = Instance.new("Folder")
boundary.Name = "Boundary"
boundary.Parent = geometry
local hw, hd = FLOOR_SIZE[1] / 2, FLOOR_SIZE[2] / 2
for _, rail in
    {
        { 0, -hd, FLOOR_SIZE[1], 1 },
        { 0, hd, FLOOR_SIZE[1], 1 },
        { -hw, 0, 1, FLOOR_SIZE[2] },
        { hw, 0, 1, FLOOR_SIZE[2] },
    }
do
    local p = part(
        boundary,
        "Rail",
        CFrame.new(world(rail[1], RAIL_HEIGHT / 2, FLOOR_CENTRE_Z + rail[2])),
        Vector3.new(rail[3], RAIL_HEIGHT, rail[4])
    )
    p.Transparency = 1
    p.CastShadow = false
end

-- ===== the concept's parts =====
-- Drawn by the game from markers, stand-ins for scale, or replaced by the lobby's own models.
local function skipped(name)
    return name == "Floor"
        or name:match("^Spawn%d")
        or name:match("^Player%d")
        or name:match("^Kit%d+Body$")
        or name:match("^Kit%d+Head$")
        or name:match("^Pad")
        or name:match("Count$")
        or name:match("Sign$") and name ~= "RangeSign"
        or name == "StoneColumn"
        or name == "PurpleColumn"
        or name:match("^Canister")
        or name:match("^Leaderboard")
        or name:match("^ArmoryCounter")
end

local ZONES = {
    { "^Corridor", "Avenue" },
    { "^Chevron", "Avenue" },
    { "^Screen", "Avenue" },
    { "^Chamber", "GateCourt" },
    { "^Gate", "GateCourt" },
    { "^DarkMatter", "GateCourt" },
    { "^Accretion", "GateCourt" },
    { "^ARMORY", "Armory" },
    { "^Rack", "Armory" },
    { "^Range", "Armory" },
    { "^Target", "Armory" },
    { "^KITS", "Kits" },
    { "^Kit", "Kits" },
    { "^Shop", "Shop" },
}
local zones = {}
local function zone(name)
    local key = "Plaza"
    for _, rule in ZONES do
        if name:match(rule[1]) then
            key = rule[2]
            break
        end
    end
    if not zones[key] then
        local folder = Instance.new("Folder")
        folder.Name = key
        folder.Parent = geometry
        zones[key] = folder
    end
    return zones[key]
end

local function colourOf(spec)
    return Color3.new(spec.colour[1], spec.colour[2], spec.colour[3])
end

-- Glowing parts are Neon; a faint glow stays a plain lit surface.
local function finish(p, spec)
    if (spec.glow or 0) >= 2 then
        p.Material = Enum.Material.Neon
        p.CastShadow = false
    end
    -- floor plates and trim sit flush on the Floor: never trip a player
    if p.Size.Y <= 0.5 and p.CFrame.Position.Y - origin.Y < 1 then
        p.CanCollide = false
    end
end

local function yaw(spec)
    return CFrame.Angles(0, math.rad(spec.rot or 0), 0)
end

-- Rings have no Roblox primitive: a loop of short blocks. A ring stands facing +z
-- (toward the arrival point) unless flat; `tilt` leans a standing ring back.
local function ring(parent, spec)
    local d, tube = spec.size[1], spec.tube or 0.3
    local r = d / 2 - tube
    local count = d > 30 and 48 or 24
    local turn
    if spec.flat then
        turn = CFrame.Angles(math.rad(90), 0, 0)
    else
        turn = CFrame.Angles(-math.rad(spec.tilt or 0), 0, 0)
    end
    local at = CFrame.new(world(spec.pos[1], spec.pos[2], spec.pos[3])) * yaw(spec) * turn
    local length = 2 * math.pi * r / count * 1.08
    for index = 0, count - 1 do
        local a = index / count * 2 * math.pi
        local segment = at * CFrame.new(r * math.cos(a), r * math.sin(a), 0) * CFrame.Angles(0, 0, a + math.pi / 2)
        local p = part(parent, spec.name, segment, Vector3.new(length, tube * 2, tube * 2), colourOf(spec))
        finish(p, spec)
        p.CanCollide = not spec.flat
    end
end

-- Lettering on a wall: an invisible plate whose Back face points the way the text faces.
local function lettering(parent, spec)
    local height = spec.size[1]
    local width = #spec.text * height * 0.8
    local p = part(
        parent,
        spec.name,
        CFrame.new(world(spec.pos[1], spec.pos[2], spec.pos[3])) * yaw(spec),
        Vector3.new(width, height * 1.3, 0.1)
    )
    p.Transparency = 1
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Back
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.LightInfluence = 0
    gui.Brightness = 2
    gui.Parent = p
    local label = Instance.new("TextLabel")
    label.Size = roblox.UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = spec.text
    label.TextScaled = true
    label.FontFace = roblox.Font.fromEnum(Enum.Font.GothamBlack)
    label.TextColor3 = colourOf(spec)
    label.Parent = gui
end

local built = 0
for _, spec in data.parts do
    if skipped(spec.name) then
        continue
    end
    built += 1
    local parent = zone(spec.name)
    local pos = world(spec.pos[1], spec.pos[2], spec.pos[3])
    local sx, sy, sz = spec.size[1], spec.size[2], spec.size[3]
    if spec.kind == "box" then
        finish(part(parent, spec.name, CFrame.new(pos) * yaw(spec), Vector3.new(sx, sy, sz), colourOf(spec)), spec)
    elseif spec.kind == "cyl" then
        -- Roblox cylinders run along x: stand it up
        local p = part(
            parent,
            spec.name,
            CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
            Vector3.new(sy, sx, sz),
            colourOf(spec)
        )
        p.Shape = Enum.PartType.Cylinder
        finish(p, spec)
    elseif spec.kind == "sphere" then
        local p = part(parent, spec.name, CFrame.new(pos), Vector3.new(sx, sx, sx), colourOf(spec))
        p.Shape = Enum.PartType.Ball
        finish(p, spec)
    elseif spec.kind == "ring" then
        ring(parent, spec)
    elseif spec.kind == "text" then
        lettering(parent, spec)
    else
        error("unknown concept part kind " .. tostring(spec.kind))
    end
end

-- A few fill lights the markers do not cover: the plaza, the avenue, the anomaly, the shop.
local fills = {
    { "PlazaFill", { 0, 24, 0 }, Color3.new(1, 0.93, 0.8), 70, 0.8 },
    { "AvenueFill", { 0, 20, -100 }, Color3.new(1, 0.9, 0.7), 70, 0.8 },
    { "AnomalyGlow", { 0, 39, -206 }, Color3.new(0.6, 0.4, 1), 60, 2 },
    { "ShopFill", { 0, 12, 125 }, Color3.new(1, 0.85, 0.6), 45, 1 },
}
for _, fill in fills do
    local anchor =
        part(zone("Plaza"), fill[1], CFrame.new(world(fill[2][1], fill[2][2], fill[2][3])), Vector3.new(1, 1, 1))
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    local light = Instance.new("PointLight")
    light.Color = fill[3]
    light.Range = fill[4]
    light.Brightness = fill[5]
    light.Shadows = false
    light.Parent = anchor
end

-- ===== markers, from Maps/Lobby.lua =====
local authoring = root.Authoring
local function marker(folder, id)
    return assert(authoring[folder]:FindFirstChild(id), ("missing marker %s/%s"):format(folder, id))
end
local function put(m, pos, size)
    m.CFrame = CFrame.new(world(pos[1], pos[2], pos[3]))
    if size then
        m.Size = size
    end
end
for index, pos in base.Spawns do
    put(marker("Spawns", tostring(index)), pos)
end
for _, spec in base.Pads do
    put(marker("QueuePads", spec.name), spec.pos, Vector3.new(table.unpack(spec.size)))
end
put(marker("Stations", "Board"), base.Board.pos, Vector3.new(table.unpack(base.Board.size)))
put(marker("Stations", "Kiosk"), base.Kiosk.pos, Vector3.new(table.unpack(base.Kiosk.size)))
for _, spec in base.Wayfinding do
    local m = authoring.Wayfinding:FindFirstChild(spec.name)
    if not m then
        m = marker("Wayfinding", "Armory"):Clone()
        m.Name = spec.name
        m:SetAttribute("Id", spec.name)
        m.Parent = authoring.Wayfinding
    end
    put(m, spec.pos, Vector3.new(spec.size[1], spec.size[2], 1))
    m:SetAttribute("Title", spec.title)
    m:SetAttribute("Detail", spec.detail)
    local colour = base.Palette[spec.color]
    if colour then
        m.Color = colour
    end
end
for _, spec in base.Lights do
    local m = marker("Lights", spec.name)
    put(m, spec.pos)
    m:SetAttribute("Range", spec.range)
    m:SetAttribute("Brightness", spec.brightness)
end

local layout, errors = Reader.read(root, base)
assert(layout, table.concat(errors, "\n"))

fs.writeDir(backupDir)
if not fs.isFile(backup) then
    fs.writeFile(backup, bytes)
end
fs.writeFile(source, roblox.serializeModel({ root }))
local count = 0
for _, item in geometry:GetDescendants() do
    if item:IsA("BasePart") then
        count += 1
    end
end
print(("Built the walk-in hub into %s: %d concept parts, %d geometry parts in all"):format(source, built, count))
print("Next: lune run tools/lobby.luau convert")
