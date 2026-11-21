-- Build the approved Faction Islands lobby (docs/design/lobby-experience/hub-concept/factions.py)
-- into the editable lobby source. Run from the project root:
--
--   python docs/design/lobby-experience/hub-concept/export_factions.py
--   lune run tools/lobbyauthor/faction_islands.luau
--   lune run tools/lobby.luau convert
--
-- A neutral Hold (arrival island, pad island, PLAY gate) with one island per faction off it:
-- Forge Union runs the armory, the Coherence Institute Alter Ego, Kade Dynamics the shop and
-- the Ferrymen the Ledger (leaderboards). The concept's blockout parts become Geometry, with
-- the art direction's materials and sign fonts. Things the game draws from markers (queue
-- pads, spawns, leaderboard, kiosk, PLAY billboard, lights) are skipped and their markers
-- moved to src/shared/Maps/Lobby.lua instead; the lobby's own stone columns, purple columns
-- and canister are kept and moved. Invisible barriers line every rim and bridge, and
-- MapService returns anyone who still falls to an arrival spawn.
--
-- Replaces Geometry wholesale, so Studio edits made since the last run are lost; the first
-- run backs up the previous source under .mapbuild/lobby-faction-islands/.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

Color3 = roblox.Color3
Vector3 = roblox.Vector3
Enum = roblox.Enum
local CFrame = roblox.CFrame
local Instance = roblox.Instance
local NumberRange = roblox.NumberRange
local NumberSequence = roblox.NumberSequence
local ColorSequence = roblox.ColorSequence

local Reader = require("../../src/shared/LobbyAuthoring")
local base = require("../../src/shared/Maps/Lobby")

local source = "assets/environment/source/Lobby.rbxm"
local design = "docs/design/lobby-experience/hub-concept/factions_parts.json"
local backupDir = ".mapbuild/lobby-faction-islands"
local backup = backupDir .. "/Lobby-before-factions.rbxm"

-- The reader needs a part called Floor that holds every spawn and queue pad. The islands are
-- round and separate, so it is an invisible footprint over the neutral spine: nobody stands
-- on it, it only bounds the markers. Narrow enough that check_lobby_authoring's 200-stud pad
-- move still lands off it.
local FOOTPRINT = { centre = { 0, -95 }, size = { 120, 290 } }

-- Columns and canister the lobby already has: where each goes, in lobby coordinates.
local STONE_SPOTS = { { -36.4, -280 }, { 36.4, -280 } } -- behind the gate, as in the concept
local PURPLE_SPOTS = {
    { 22, 55 }, -- arrival, behind the spawns
    { -24, -66 }, -- pad island: gateposts at the end of the arrival bridge
    { 24, -66 },
    { -48, -250 }, -- gate island, an arc either side of the gate
    { 48, -250 },
    { -41.6, -231 },
    { 41.6, -231 },
    { 0, -302 }, -- behind the gate
}
local CANISTER_SPOT = { -22, 52 } -- arrival, behind the spawns: the season display

local bytes = fs.readFile(source)
local root = roblox.deserializeModel(bytes)[1]
assert(root and root:GetAttribute("LobbySource") == true, "expected the editable Lobby model")
local origin = Vector3.new(table.unpack(base.Origin))
local data = serde.decode("json", fs.readFile(design))

local function world(x, y, z)
    return origin + Vector3.new(x, y, z)
end

-- ===== keep the lobby's own models, drop everything else =====
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

-- ===== helpers =====
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

local function ghost(p)
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
end

local floor = part(
    geometry,
    "Floor",
    CFrame.new(world(FOOTPRINT.centre[1], -1, FOOTPRINT.centre[2])),
    Vector3.new(FOOTPRINT.size[1], 2, FOOTPRINT.size[2])
)
floor.Transparency = 1
floor.CastShadow = false
ghost(floor)
floor:SetAttribute("Note", "Marker footprint only: spawns and queue pads must sit inside it. Not walkable.")

-- ===== the concept's parts =====
local function skipped(name)
    return name:match("^Spawn%d")
        or name:match("^Player%d")
        or name:match("^Kit%d+Body$")
        or name:match("^Kit%d+Head$")
        or name:match("^Pad")
        or name:match("^Screen.*Count$") -- pad player counts are drawn live; DayCount is not one
        or name == "StoneColumn"
        or name == "PurpleColumn"
        or name:match("^Canister")
        or name:match("^Leaderboard")
        or name:match("^ArmoryCounter")
end

-- One folder per place, so a designer can hide an island in Studio.
local FOLDERS = {
    Forge = "ForgeUnion",
    Institute = "CoherenceInstitute",
    Kade = "KadeDynamics",
    Ferrymen = "Ferrymen",
}
local folders = {}
local function folderFor(spec)
    local key
    if spec.invisible then
        key = "Barriers"
    elseif spec.name:match("^Bridge") then
        key = "Bridges"
    elseif spec.side ~= "Hold" then
        key = FOLDERS[spec.side]
    elseif spec.pos[3] < -180 then
        key = "GateIsland"
    elseif spec.pos[3] < -40 then
        key = "PadIsland"
    else
        key = "Hold"
    end
    if not folders[key] then
        local folder = Instance.new("Folder")
        folder.Name = key
        folder.Parent = geometry
        folders[key] = folder
    end
    return folders[key]
end

local function colourOf(spec)
    return Color3.new(spec.colour[1], spec.colour[2], spec.colour[3])
end

local function finish(p, spec)
    if spec.material then
        p.Material = Enum.Material[spec.material]
    end
    -- glowing parts are Neon; a faint glow stays a plain lit surface
    if (spec.glow or 0) >= 2 then
        p.Material = Enum.Material.Neon
        p.CastShadow = false
    end
    -- floor plates and trim sit flush on the deck: never trip a player
    if p.Size.Y <= 0.5 and p.CFrame.Position.Y - origin.Y < 1 then
        p.CanCollide = false
    end
    if spec.ghost then
        ghost(p)
        p.CastShadow = false
    end
end

local function yaw(spec)
    return CFrame.Angles(0, math.rad(spec.rot or 0), 0)
end

-- Rings have no Roblox primitive: a loop of short blocks. A ring stands facing +z unless flat;
-- `tilt` leans a standing ring back.
local function ring(parent, spec)
    local d, tube = spec.size[1], spec.tube or 0.3
    local r = d / 2 - tube
    local count = d > 30 and 48 or d > 10 and 24 or 12
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
        p.CanCollide = not spec.flat and spec.pos[2] < 12
    end
end

-- Lettering: an invisible plate carrying a SurfaceGui. Standing text reads from the plate's
-- Back face (the way the concept's text faces); flat text lies on the deck and reads from above.
local function lettering(parent, spec)
    local height = spec.size[1]
    local width = #spec.text * height * 0.8
    local at = CFrame.new(world(spec.pos[1], spec.pos[2], spec.pos[3])) * yaw(spec)
    local size = spec.flat and Vector3.new(width, 0.1, height * 1.3) or Vector3.new(width, height * 1.3, 0.1)
    local p = part(parent, spec.name, at, size)
    p.Transparency = 1
    p.CastShadow = false
    ghost(p)
    local gui = Instance.new("SurfaceGui")
    gui.Face = spec.flat and Enum.NormalId.Top or Enum.NormalId.Back
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.LightInfluence = 0
    gui.Brightness = (spec.glow or 0) >= 2 and 2 or 1
    gui.Parent = p
    local label = Instance.new("TextLabel")
    label.Size = roblox.UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = spec.text
    label.TextScaled = true
    -- the art direction's Roblox font families; not every family has an Enum.Font entry
    label.FontFace = spec.font
            and roblox.Font.new(
                ("rbxasset://fonts/families/%s.json"):format(spec.font),
                spec.font == "Oswald" and Enum.FontWeight.Bold or Enum.FontWeight.Regular
            )
        or roblox.Font.fromEnum(Enum.Font.GothamBlack)
    label.TextColor3 = colourOf(spec)
    label.Parent = gui
end

local built = 0
local named = {}
for _, spec in data.parts do
    if skipped(spec.name) then
        continue
    end
    built += 1
    local parent = folderFor(spec)
    local pos = world(spec.pos[1], spec.pos[2], spec.pos[3])
    local sx, sy, sz = spec.size[1], spec.size[2], spec.size[3]
    local made
    if spec.kind == "box" then
        made = part(parent, spec.name, CFrame.new(pos) * yaw(spec), Vector3.new(sx, sy, sz), colourOf(spec))
        if spec.invisible then
            made.Transparency = 1
            made.CastShadow = false
            made.CanQuery = false
            made.CanTouch = false
        end
        finish(made, spec)
    elseif spec.kind == "cyl" then
        -- Roblox cylinders run along x: stand it up
        made = part(
            parent,
            spec.name,
            CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
            Vector3.new(sy, sx, sz),
            colourOf(spec)
        )
        made.Shape = Enum.PartType.Cylinder
        finish(made, spec)
    elseif spec.kind == "sphere" then
        if sx == sy and sy == sz then
            made = part(parent, spec.name, CFrame.new(pos), Vector3.new(sx, sx, sx), colourOf(spec))
            made.Shape = Enum.PartType.Ball
        else
            -- a squashed sphere (coin, rocket nose, drone, steam): a block drawn as a sphere
            made = part(parent, spec.name, CFrame.new(pos) * yaw(spec), Vector3.new(sx, sy, sz), colourOf(spec))
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.Sphere
            mesh.Parent = made
            made.CanCollide = false
        end
        finish(made, spec)
    elseif spec.kind == "ring" then
        ring(parent, spec)
    elseif spec.kind == "text" then
        lettering(parent, spec)
    else
        error("unknown concept part kind " .. tostring(spec.kind))
    end
    if made then
        named[spec.name] = named[spec.name] or {}
        table.insert(named[spec.name], made)
    end
end

-- Translucent effects stand-ins: steam and frost plumes are haze, not solids.
for _, name in { "Steam", "FrostPlume" } do
    for _, p in named[name] or {} do
        p.Transparency = 0.45
    end
end

-- ===== effects: at most two emitters per island, low rates (art direction) =====
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local function emitter(host, props)
    local e = Instance.new("ParticleEmitter")
    e.Texture = props.texture
    e.Color = ColorSequence.new(props.colour)
    e.Rate = props.rate
    e.Lifetime = NumberRange.new(props.life[1], props.life[2])
    e.Speed = NumberRange.new(props.speed[1], props.speed[2])
    e.SpreadAngle = roblox.Vector2.new(props.spread, props.spread)
    e.Size = NumberSequence.new(props.size[1], props.size[2])
    e.Transparency = NumberSequence.new(props.fade[1], props.fade[2])
    e.LightEmission = props.light or 0
    e.Acceleration = props.accel or Vector3.new(0, 0, 0)
    e.EmissionDirection = Enum.NormalId.Top
    e.Parent = host
    return e
end
local function first(name, pick)
    local list = named[name] or {}
    if pick then
        table.sort(list, function(a, b)
            return pick(a) > pick(b)
        end)
    end
    return list[1]
end
-- Forge Union: weld sparks at the bench, smoke from the tall chimney
local arc = first("WeldArc")
if arc then
    emitter(arc, {
        texture = SPARKLE,
        colour = Color3.new(1, 0.75, 0.3),
        rate = 12,
        life = { 0.3, 0.7 },
        speed = { 6, 12 },
        spread = 60,
        size = { 0.35, 0.05 },
        fade = { 0, 1 },
        light = 1,
        accel = Vector3.new(0, -30, 0),
    })
end
local chimney = first("Chimney", function(p)
    return p.Size.X -- cylinders lie on x: x is the height
end)
if chimney then
    local top = part(
        chimney.Parent,
        "ChimneySmoke",
        CFrame.new(chimney.CFrame.Position + Vector3.new(0, chimney.Size.X / 2, 0)),
        Vector3.new(4, 0.2, 4)
    )
    top.Transparency = 1
    ghost(top)
    emitter(top, {
        texture = SMOKE,
        colour = Color3.new(0.25, 0.22, 0.2),
        rate = 3,
        life = { 5, 7 },
        speed = { 3, 5 },
        spread = 12,
        size = { 3, 9 },
        fade = { 0.4, 1 },
    })
end
-- Coherence Institute: cold mist from the two vents nearest the bridge
local vents = named.FrostVent or {}
table.sort(vents, function(a, b)
    return (a.CFrame.Position - world(0, 0, 30)).Magnitude < (b.CFrame.Position - world(0, 0, 30)).Magnitude
end)
for index = 1, math.min(2, #vents) do
    emitter(vents[index], {
        texture = SMOKE,
        colour = Color3.new(0.82, 0.95, 1),
        rate = 4,
        life = { 3, 4 },
        speed = { 1, 2 },
        spread = 25,
        size = { 1.5, 4 },
        fade = { 0.5, 1 },
    })
end
-- Kade Dynamics: steam venting at the rocket's feet
local pad = first("LaunchPad")
if pad then
    emitter(pad, {
        texture = SMOKE,
        colour = Color3.new(0.9, 0.92, 0.95),
        rate = 5,
        life = { 2, 3 },
        speed = { 2, 4 },
        spread = 70,
        size = { 2, 6 },
        fade = { 0.45, 1 },
    })
end

-- ===== fill lights the markers do not cover =====
local fills = {
    { "HoldFill", { 0, 18, 30 }, Color3.new(1, 0.72, 0.4), 55, 0.7 }, -- amber emergency light
    { "KadeFill", { 150, 26, 112 }, Color3.new(1, 0.85, 0.55), 70, 1.6 },
    { "AnomalyGlow", { 0, 40, -270 }, Color3.new(0.6, 0.4, 1), 60, 2 },
}
for _, fill in fills do
    local anchor = part(
        folders.Hold or geometry,
        fill[1],
        CFrame.new(world(fill[2][1], fill[2][2], fill[2][3])),
        Vector3.new(1, 1, 1)
    )
    anchor.Transparency = 1
    ghost(anchor)
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
local function put(m, pos, size, turn)
    m.CFrame = CFrame.new(world(pos[1], pos[2], pos[3])) * CFrame.Angles(0, math.rad(turn or 0), 0)
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
put(marker("Stations", "Board"), base.Board.pos, Vector3.new(table.unpack(base.Board.size)), base.Board.yaw)
put(marker("Stations", "Kiosk"), base.Kiosk.pos, Vector3.new(table.unpack(base.Kiosk.size)), base.Kiosk.yaw)

-- Wayfinding: only the markers Maps/Lobby.lua still declares survive. The islands name
-- themselves in surface lettering that faces the arrival island.
local wanted = {}
for _, spec in base.Wayfinding do
    wanted[spec.name] = true
end
local template = authoring.Wayfinding:GetChildren()[1]
for _, spec in base.Wayfinding do
    local m = authoring.Wayfinding:FindFirstChild(spec.name)
    if not m then
        m = template:Clone()
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
for _, m in authoring.Wayfinding:GetChildren() do
    if not wanted[m.Name] then
        m:Destroy()
    end
end

for _, spec in base.Lights do
    local m = marker("Lights", spec.name)
    put(m, spec.pos)
    m:SetAttribute("Range", spec.range)
    m:SetAttribute("Brightness", spec.brightness)
    local colour = base.Palette[spec.color]
    if colour then
        m.Color = colour
    end
end

local layout, errors = Reader.read(root, base)
assert(layout, table.concat(errors, "\n"))

fs.writeDir(backupDir)
if not fs.isFile(backup) then
    fs.writeFile(backup, bytes)
end
fs.writeFile(source, roblox.serializeModel({ root }))
local count, invisible = 0, 0
for _, item in geometry:GetDescendants() do
    if item:IsA("BasePart") then
        count += 1
        if item.Transparency >= 1 then
            invisible += 1
        end
    end
end
print(
    ("Built Faction Islands into %s: %d concept parts, %d geometry parts (%d invisible)"):format(
        source,
        built,
        count,
        invisible
    )
)
print("Next: lune run tools/lobby.luau convert")
